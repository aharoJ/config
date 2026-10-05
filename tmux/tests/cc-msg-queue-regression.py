#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

loader = importlib.machinery.SourceFileLoader('queue', str(Path(__file__).resolve().parents[1] / 'tools/cc-msg-queue'))
spec = importlib.util.spec_from_loader(loader.name, loader)
queue = importlib.util.module_from_spec(spec)
loader.exec_module(queue)


class QueueTests(unittest.TestCase):
    def setUp(self):
        self.root = Path.home() / 'desk/lab/cc-msg-queue-tests' / uuid.uuid4().hex
        self.root.mkdir(parents=True)
        self.identity = dict(socket='/test/socket', device=1, inode=2, pane='%8', pid='123')
        self.env = dict(CC_MSG_SESSION='lab-test', CC_MSG_WINDOW='claude', TMUX='/test/socket,1,2')

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
            code, output = queue.deliver(dict(message='--help', identity=self.identity), self.env)
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
