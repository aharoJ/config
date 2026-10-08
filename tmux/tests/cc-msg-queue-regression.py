#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import signal
import subprocess
import sys
import time

loader = importlib.machinery.SourceFileLoader('queue', str(Path(__file__).resolve().parents[1] / 'tools/cc-msg-queue'))
spec = importlib.util.spec_from_loader(loader.name, loader)
queue = importlib.util.module_from_spec(spec)
loader.exec_module(queue)


class QueueTests(unittest.TestCase):
    def test_unbound_warning_preserves_delivery_and_queue_exit_codes(self):
        for code, expected in ((0, 0), (5, 6)):
            with self.subTest(code=code):
                self.root = self.root / uuid.uuid4().hex
                warning = 'target lab-test:claude is unbound: it cannot reply until bound'
                with patch.dict(os.environ, RELAY_REPLY_WARNING='1'), patch.dict(queue.STARTED, reply_warning=lambda *args:warning):
                    result, path, data, launch = self.send(code)
                self.assertEqual(result, expected)
                self.assertEqual(data['reply_warning'], warning)

    def test_watch_only_arms_after_verified_delivery(self):
        with patch.dict(os.environ, RELAY_WATCH_MINUTES='1'), patch.dict(queue.STARTED, snapshot=lambda *args:'baseline'):
            result, path, data, launch = self.send(0)
        self.assertEqual(result, 0)
        self.assertEqual(data['watch_baseline'], 'baseline')
        self.assertEqual(launch.call_args.args[0][-2:], ['--watch-worker', str(path)])
        self.root = self.root / uuid.uuid4().hex
        with patch.dict(os.environ, RELAY_WATCH_MINUTES='1'), patch.dict(queue.STARTED, snapshot=lambda *args:'baseline'):
            result, path, data, launch = self.send(5)
        self.assertEqual(result, 6)
        self.assertNotIn('watch_baseline', data)

    def setUp(self):
        def unavailable(*args):
            raise ValueError('unit fixture has no actual target')
        advisory = patch.dict(queue.STARTED, reply_warning=lambda *args:None, snapshot=unavailable)
        advisory.start()
        self.addCleanup(advisory.stop)
        route = patch.object(queue, 'routing_source', return_value=dict(session='lab-test', window='codex', pane='%1'))
        route.start()
        self.addCleanup(route.stop)
        self.root = Path(os.environ.get('RELAY_TEST_ROOT', str(Path.home() / 'desk/lab/cc-msg-queue-tests'))) / uuid.uuid4().hex
        self.root.mkdir(parents=True)
        self.identity = dict(socket='/test/socket', device=1, inode=2, pane='%8', pid='123')
        self.env = dict(CC_MSG_SESSION='lab-test', CC_MSG_WINDOW='claude', TMUX='/test/socket,1,2')

    def test_started_check_defaults_to_ten_minutes_without_opt_in(self):
        with patch.dict(queue.STARTED, snapshot=lambda *args:'baseline'):
            result, path, data, launch = self.send(0)
        self.assertEqual(result, 0)
        self.assertEqual(data['watch_minutes'], 10)
        self.assertEqual(data['started_state'], 'unobserved')
        self.assertEqual(launch.call_args.args[0][-2:], ['--watch-worker', str(path)])

    def send(self, code):
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'deliver', return_value=(code, 'test outcome')), patch.object(queue, 'stable_screen', return_value=True), patch.object(queue.subprocess, 'Popen') as launch, patch.dict(os.environ, self.env), patch.object(queue.sys, 'argv', ['cc-msg', 'payload']):
            launch.return_value.pid = 999
            result = queue.main()
        path = next(self.root.glob('*/*.json'))
        data = json.loads(path.read_text())
        events = [json.loads(line) for line in (path.parent / 'inbox.jsonl').read_text().splitlines()]
        self.assertEqual(events[0]['message'], 'payload')
        self.assertEqual(data['identity'], self.identity)
        return result, path, data, launch

    def test_interrupted_initial_attempt_is_unknown_and_never_queued(self):
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'stable_screen', return_value=True), patch.object(queue, 'deliver', side_effect=InterruptedError('transport interrupted after possible paste')), patch.object(queue, 'launch_worker') as launch, patch.dict(os.environ, self.env), patch.object(queue.sys, 'argv', ['cc-msg', 'payload']):
            self.assertEqual(queue.main(), 4)
        data = json.loads(next(self.root.glob('*/*.json')).read_text())
        self.assertEqual(data['state'], 'unknown')
        self.assertEqual(data['code'], 4)
        self.assertIn('interrupted', data['output'])
        launch.assert_not_called()

    def test_initial_sigterm_stops_transport_and_persists_unknown(self):
        marker = self.root / 'possible-paste-marker'
        transport = self.root / 'transport'
        transport.write_text('#!' + sys.executable + "\nimport os,time,pathlib\npathlib.Path(" + repr(str(marker)) + ").write_text(str(os.getpid()))\ntime.sleep(120)\n")
        transport.chmod(0o700)
        driver = self.root / 'driver.py'
        driver.write_text("import importlib.machinery,pathlib,os,sys\nq=importlib.machinery.SourceFileLoader('queue', " + repr(str(Path(queue.__file__))) + ").load_module()\nq.ROOT=pathlib.Path(" + repr(str(self.root / 'inbox')) + ")\nq.TOOL=pathlib.Path(" + repr(str(transport)) + ")\nq.deliver=q.transport\nq.routing_source=lambda *a:dict(session='lab-test',window='codex',pane='%1')\nq.resolve_defaults=lambda e,a:e\nq.identity=lambda e:" + repr(self.identity) + "\nq.stable_screen=lambda *a:True\nos.environ.update(" + repr(self.env) + ")\nsys.argv=['queue','payload']\nsys.exit(q.main())\n")
        process = subprocess.Popen([sys.executable, str(driver)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            until = time.monotonic() + 5
            while not marker.exists() and time.monotonic() < until:
                time.sleep(.02)
            self.assertTrue(marker.exists())
            child = int(marker.read_text())
            process.send_signal(signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 4, stdout + stderr)
            data = json.loads(next((self.root / 'inbox').glob('*/*.json')).read_text())
            self.assertEqual(data['state'], 'unknown')
            self.assertIn('signal', data['output'])
            with self.assertRaises(ProcessLookupError):
                os.kill(child, 0)
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

    def test_operator_options_keep_legacy_codex_order_and_targeted_literals(self):
        for arguments, expected_operator in [(['--codex', '-O', 'payload'], True),
                                             (['--codex', '--operator', 'payload'], True),
                                             (['--operator', '--codex', 'payload'], True),
                                             (['--codex-to', 'codex', '--operator'], False)]:
            with self.subTest(arguments=arguments):
                root = self.root / uuid.uuid4().hex
                env = dict(self.env, CODEX_SEND_SESSION='lab-test', CODEX_SEND_WINDOW='codex')
                with patch.object(queue, 'ROOT', root), patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'deliver', return_value=(0, 'test outcome')) as deliver, patch.object(queue, 'stable_screen', return_value=True), patch.dict(os.environ, env), patch.object(queue.sys, 'argv', ['queue', *arguments]):
                    self.assertEqual(queue.main(), 0)
                data = json.loads(next(root.glob('*/*.json')).read_text())
                self.assertEqual(data['operator'], expected_operator)
                self.assertEqual(data['message'], 'payload' if expected_operator else '--operator')
                self.assertEqual(deliver.call_args.args[1]['RELAY_OPERATOR'], '1' if expected_operator else '0')

    def test_codex_transport_and_operator_are_explicit(self):
        process = type('Process', (), {'returncode': 0, 'communicate': lambda self, text, timeout: ('delivered', '')})()
        with patch.object(queue.subprocess, 'Popen', return_value=process) as launch:
            queue.transport(dict(agent='codex', operator=True, message='replace draft', identity=self.identity), self.env)
        self.assertEqual(launch.call_args.args[0], [str(queue.TOOL.with_name('codex-send'))])
        env = launch.call_args.kwargs['env']
        self.assertEqual(env['CODEX_SEND_QUEUE_INTERNAL'], '1')
        self.assertEqual(env['RELAY_OPERATOR'], '1')
        self.assertIn('CC_MSG_EXPECT_IDENTITY', env)

    def test_targeted_codex_retains_transport_and_binding(self):
        process = type('Process', (), {'returncode': 0, 'communicate': lambda self, text, timeout: ('delivered', '')})()
        env = dict(self.env, CODEX_SEND_WINDOW='codex-review')
        with patch.object(queue.subprocess, 'Popen', return_value=process) as launch:
            queue.transport(dict(agent='codex-to', message='standing instruction', identity=self.identity), env)
        self.assertEqual(launch.call_args.args[0], [str(queue.TOOL.with_name('codex-send-to')), 'codex-review'])
        self.assertEqual(json.loads(launch.call_args.kwargs['env']['CC_MSG_EXPECT_IDENTITY']), self.identity)
        self.assertEqual(launch.call_args.kwargs['env']['CODEX_SEND_QUEUE_INTERNAL'], '1')

    def test_targeted_codex_defaults_use_codex_namespace(self):
        env = dict(CODEX_SEND_SESSION='lab-test', CODEX_SEND_WINDOW='codex-review', TMUX='/test/socket,1,2')
        resolved = queue.resolve_defaults(env, 'codex-to')
        self.assertEqual((resolved['CC_MSG_SESSION'], resolved['CC_MSG_WINDOW']), ('lab-test', 'codex-review'))
        self.assertEqual(resolved['RELAY_QUEUE_AGENT'], 'codex-to')

    def test_targeted_codex_payload_options_remain_literal(self):
        env = dict(self.env, CODEX_SEND_SESSION='lab-test')
        for message in ('--status', '--help', '-h', '--operator', '-O', '--codex', '--worker', '', 'two words'):
            with self.subTest(message=message), patch.object(queue, 'ROOT', self.root), patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'stable_screen', return_value=True), patch.object(queue, 'deliver', return_value=(0, 'delivered')) as deliver, patch.dict(os.environ, env), patch.object(queue.sys, 'argv', ['queue', '--codex-to', 'codex-review', message]):
                self.assertEqual(queue.main(), 0)
            data, transport_env = deliver.call_args.args
            self.assertEqual(data['message'], message)
            self.assertEqual(data['agent'], 'codex-to')
            self.assertFalse(data['operator'])
            self.assertEqual(transport_env['CODEX_SEND_WINDOW'], 'codex-review')

    def test_targeted_codex_rejects_missing_or_extra_payload_arguments(self):
        for args in (['queue', '--codex-to', 'codex'], ['queue', '--codex-to', 'codex', 'text', 'extra']):
            with self.subTest(args=args), patch.object(queue.sys, 'argv', args), patch.object(queue, 'deliver') as deliver:
                with self.assertRaises(queue.RoutingError):
                    queue.main()
            deliver.assert_not_called()

    def test_defaults_bind_caller_pane_before_index_resolution(self):
        response = lambda text: type('Result', (), {'returncode': 0, 'stdout': text})()
        env = dict(TMUX='/test/socket,1,2', TMUX_PANE='%9', CC_MSG_WINDOW='2')
        with patch.object(queue.subprocess, 'run', side_effect=[response('%9|caller\n'), response('1|notes\n2|claude\n')]) as request:
            resolved = queue.resolve_defaults(env, 'claude')
        self.assertEqual((resolved['CC_MSG_SESSION'], resolved['CC_MSG_WINDOW']), ('caller', 'claude'))
        self.assertIn('%9', request.call_args_list[0].args[0])

    def test_missing_caller_cannot_default_to_another_pane(self):
        env = dict(TMUX='/test/socket,1,2', TMUX_PANE='%9')
        result = type('Result', (), {'returncode': 0, 'stdout': '%1|other\n'})()
        with patch.object(queue.subprocess, 'run', return_value=result):
            with self.assertRaises(ValueError):
                queue.resolve_defaults(env, 'claude')

    def test_operator_unknown_outcome_is_not_queued(self):
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'deliver', return_value=(4, 'clear may have happened')) as deliver, patch.object(queue, 'stable_screen', return_value=False), patch.object(queue.subprocess, 'Popen') as launch, patch.dict(os.environ, self.env), patch.object(queue.sys, 'argv', ['cc-msg', '--operator', 'replacement']):
            self.assertEqual(queue.main(), 4)
        deliver.assert_called_once()
        launch.assert_not_called()
        data = json.loads(next(self.root.glob('*/*.json')).read_text())
        self.assertTrue(data['operator'])
        self.assertEqual(data['state'], 'unknown')

    def test_safe_refusals_have_retry_owner(self):
        for code in (2, 5):
            result, path, data, launch = self.send(code)
            self.assertEqual((result, data['state']), (6, 'queued'))
            launch.assert_called_once()
            self.assertEqual(launch.call_args.kwargs['stdin'], queue.subprocess.DEVNULL)
            self.assertTrue(launch.call_args.kwargs['start_new_session'])
            self.root = self.root / str(code)
            self.root.mkdir()

    def test_uncertain_or_invalid_never_retry(self):
        for code in (0, 1, 3, 4):
            result, path, data, launch = self.send(code)
            self.assertEqual(result, code)
            launch.assert_not_called()
            self.assertEqual(data['state'], 'delivered' if code == 0 else 'unknown' if code in (3, 4) else 'failed')
            self.assertEqual(path.with_suffix('.FAILED').exists(), code != 0)
            self.root = self.root / str(code)
            self.root.mkdir()

    def test_worker_delivers_once_and_stops_after_unknown(self):
        for code in (0, 3, 4):
            _, path, _, _ = self.send(5)
            with patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'stable_screen', return_value=True), patch.object(queue.time, 'sleep'), patch.object(queue, 'deliver', return_value=(code, 'outcome')) as deliver:
                queue.worker(path)
                queue.worker(path)
            deliver.assert_called_once()
            self.assertEqual(json.loads(path.read_text())['code'], code)
            self.root = self.root / str(code)
            self.root.mkdir()

    def test_replaced_target_is_not_typed_into(self):
        _, path, _, _ = self.send(5)
        with patch.object(queue, 'identity', return_value=dict(self.identity, pid='999')), patch.object(queue.time, 'sleep'), patch.object(queue, 'deliver') as deliver:
            queue.worker(path)
        deliver.assert_not_called()
        self.assertTrue(path.with_suffix('.FAILED').exists())

    def test_expiry_is_visible(self):
        _, path, data, _ = self.send(5)
        data['deadline'] = 0
        queue.save(path, data)
        with patch.object(queue, 'deliver') as deliver:
            queue.worker(path)
        deliver.assert_not_called()
        self.assertEqual(json.loads(path.read_text())['state'], 'expired')
        self.assertTrue(path.with_suffix('.FAILED').exists())

    def test_transport_uses_stdin_and_bounds_tmux(self):
        process = type('Process', (), {'returncode': 0, 'communicate': lambda self, text, timeout: ('delivered', '')})()
        with patch.object(queue.subprocess, 'Popen', return_value=process) as launch:
            code, output = queue.transport(dict(message='--help', identity=self.identity), self.env)
        self.assertEqual((code, output), (0, 'delivered'))
        self.assertEqual(launch.call_args.args[0], [str(queue.TOOL)])
        self.assertEqual(launch.call_args.kwargs['stdin'], queue.subprocess.PIPE)
        env = launch.call_args.kwargs['env']
        self.assertEqual((env['CC_MSG_PANE'], env['CC_MSG_EXPECT_PID']), ('%8', '123'))
        self.assertEqual((env['TMUX_TIMEOUT_SECONDS'], env['TMUX_TIMEOUT_KILL_AFTER'], env['CC_MSG_QUEUE_STRICT']), ('1', '1', '1'))

    def test_pending_message_detection_is_scoped_to_composer(self):
        def capture(stdout):
            return type('Capture', (), {'returncode': 0, 'stdout': stdout})()
        target = self.identity
        old_marker = b'ctrl+x ctrl+s to send now\n' + b'old transcript\n' * 10 + b'new response\n' * 10 + b'divider\n' + '❯ '.encode() + b'\ndivider\n'
        state = capture('0:22\n')
        with patch.object(queue.subprocess, 'run', side_effect=[capture(old_marker), capture(old_marker), state]), patch.object(queue.time, 'sleep'):
            self.assertTrue(queue.stable_screen(self.env, target))
        pending = b'old transcript\n' * 20 + b'ctrl+x ctrl+s to send now\ndivider\n' + '❯ Press up to edit queued messages'.encode() + b'\n'
        with patch.object(queue.subprocess, 'run', side_effect=[capture(pending), capture(pending), state]), patch.object(queue.time, 'sleep'):
            self.assertFalse(queue.stable_screen(self.env, target))

    def test_worker_launch_failure_is_recorded(self):
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'stable_screen', return_value=True), patch.object(queue, 'deliver', return_value=(5, 'refused')), patch.object(queue.subprocess, 'Popen', side_effect=OSError('launch denied')), patch.dict(os.environ, self.env), patch.object(queue.sys, 'argv', ['cc-msg', 'payload']):
            self.assertEqual(queue.main(), 7)
        path = next(self.root.glob('*/*.json'))
        self.assertEqual(json.loads(path.read_text())['state'], 'failed')
        self.assertTrue(path.with_suffix('.FAILED').exists())

    def test_persistence_failure_prevents_delivery(self):
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'save', side_effect=OSError('disk full')), patch.object(queue, 'deliver') as deliver, patch.dict(os.environ, self.env), patch.object(queue.sys, 'argv', ['cc-msg', 'payload']):
            with self.assertRaises(OSError):
                queue.main()
        deliver.assert_not_called()

    def test_initial_changing_screen_queues_without_paste(self):
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'stable_screen', return_value=False), patch.object(queue, 'deliver') as deliver, patch.object(queue.subprocess, 'Popen', return_value=type('Process', (), {'pid': 999})()), patch.dict(os.environ, self.env), patch.object(queue.sys, 'argv', ['cc-msg', 'payload']):
            self.assertEqual(queue.main(), 6)
        deliver.assert_not_called()

    def test_orphaned_queue_recovers_and_expired_queue_marks_failure(self):
        _, path, data, _ = self.send(5)
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'launch_worker') as launch:
            queue.sweep()
        launch.assert_called_once()
        data['deadline'] = 0
        queue.save(path, data)
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'launch_worker') as launch:
            queue.sweep()
        launch.assert_not_called()
        self.assertTrue(path.with_suffix('.FAILED').exists())

    def test_orphaned_attempt_is_never_retried(self):
        _, path, data, _ = self.send(5)
        data.update(state='attempting', updated=0)
        queue.save(path, data)
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'launch_worker') as launch:
            queue.sweep()
        launch.assert_not_called()
        self.assertEqual(json.loads(path.read_text())['state'], 'unknown')
        self.assertTrue(path.with_suffix('.FAILED').exists())

    def test_orphaned_clear_is_unknown_and_never_retried(self):
        _, path, data, _ = self.send(5)
        data.update(state='clear-authorized', operation='clear-draft', updated=0)
        queue.save(path, data)
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'launch_worker') as launch:
            queue.sweep()
        launch.assert_not_called()
        self.assertEqual(json.loads(path.read_text())['state'], 'unknown')
        self.assertTrue(path.with_suffix('.FAILED').exists())

    def test_orphaned_inspection_refuses_without_keys(self):
        _, path, data, _ = self.send(5)
        data.update(state='clear-inspecting', operation='clear-draft', created=0)
        queue.save(path, data)
        with patch.object(queue, 'ROOT', self.root), patch.object(queue, 'launch_worker') as launch:
            queue.sweep()
        launch.assert_not_called()
        self.assertEqual(json.loads(path.read_text())['state'], 'clear-refused')
        self.assertEqual(json.loads(path.read_text())['code'], 8)

    def test_status_sweep_cannot_overwrite_active_worker(self):
        _, path, data, _ = self.send(5)
        data['deadline'] = 0
        queue.save(path, data)
        with path.with_suffix('.lock').open('a') as lock:
            queue.fcntl.flock(lock, queue.fcntl.LOCK_EX)
            with patch.object(queue, 'ROOT', self.root):
                queue.sweep()
        self.assertEqual(json.loads(path.read_text())['state'], 'queued')
        self.assertFalse(path.with_suffix('.FAILED').exists())

    def test_interruption_during_transport_never_retries(self):
        _, path, _, _ = self.send(5)
        with patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'stable_screen', return_value=True), patch.object(queue.time, 'sleep'), patch.object(queue, 'deliver', side_effect=RuntimeError('signal 15')):
            with self.assertRaises(RuntimeError):
                queue.worker(path)
        self.assertEqual(json.loads(path.read_text())['state'], 'unknown')
        self.assertTrue(path.with_suffix('.FAILED').exists())

    def test_changing_screen_does_not_paste(self):
        _, path, data, _ = self.send(5)
        ticks = iter([data['deadline'] - 1, data['deadline'] - 1, data['deadline'] - 1, data['deadline'] + 1, data['deadline'] + 1, data['deadline'] + 1])
        with patch.object(queue.time, 'time', side_effect=lambda: next(ticks, data['deadline'] + 1)), patch.object(queue.time, 'sleep'), patch.object(queue, 'identity', return_value=self.identity), patch.object(queue, 'stable_screen', return_value=False), patch.object(queue, 'deliver') as deliver:
            queue.worker(path)
        deliver.assert_not_called()


if __name__ == '__main__':
    unittest.main()
