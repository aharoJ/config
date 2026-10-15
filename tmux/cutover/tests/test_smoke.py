import importlib.util
import json
import os
from pathlib import Path
import shlex
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('cutover_smoke', Path(__file__).resolve().parents[1] / 'smoke.py')
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class Kernel:
    def identity(self, pid):
        return [pid, 100, 1]


def pane(pid=11, window='@9', title='s6x-smoke-123456abcdef'):
    return dict(session='$3', name=smoke.SESSION, window=window, title=title, pid=pid, command='sleep')


class SmokeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='s6x-smoke-test-', dir=Path.home() / 'desk/tmp')
        self.home = Path(self.directory.name)

    def tearDown(self):
        self.directory.cleanup()

    def approval(self):
        package = self.home / 'desk/relay-packages' / ('rust-' + 'a' * 40)
        package.mkdir(parents=True)
        (package / 'launch').write_text('fixture')
        (self.home / '.local/bin').mkdir(parents=True)
        for name in smoke.SURFACES:
            (self.home / '.local/bin' / name).symlink_to(package / 'launch')
        (self.home / 'desk/tmp/relay').mkdir(parents=True)
        store = self.home / 'desk/relay-store-v1'
        store.mkdir()
        return dict(schema='relay-cutover-smoke-v1', scope='owned-window-refusal', driver_sha256=smoke.digest(smoke.__file__),
                    uid=os.geteuid(), socket='/private/tmp/tmux-%d/default' % os.geteuid(), session=smoke.SESSION,
                    session_id='$3', server=[5, 100, 1], socket_identity=[7, 8], window_name='s6x-smoke-123456abcdef',
                    root=str(self.home / 'desk/tmp/relay/s6x-smoke-123456abcdef'),
                    entries={name: str(self.home / '.local/bin' / name) for name in smoke.SURFACES},
                    package=str(package), package_inventory=smoke.package_inventory(package), store=str(store))

    def test_approval_pins_complete_package_and_fresh_root(self):
        value = self.approval()
        smoke.validate_approval(value, self.home)
        Path(value['package'], 'unreviewed').write_text('changed')
        with self.assertRaisesRegex(smoke.Refused, 'inventory'):
            smoke.validate_approval(value, self.home)

    def test_native_scope_consumed_pin_and_wrong_route_refuse(self):
        value = self.approval()
        for mutation in [dict(scope='native-matrix'), dict(driver_sha256='0' * 64), dict(session='config'),
                         dict(socket='/private/tmp/other'), dict(window_name='claude'),
                         dict(server=[5, 0, 1]), dict(socket_identity=[7, 0]), dict(session_id='config')]:
            with self.subTest(mutation=mutation), self.assertRaises(smoke.Refused):
                smoke.validate_approval(dict(value, **mutation), self.home)
        Path(value['root']).mkdir()
        with self.assertRaisesRegex(smoke.Refused, 'fresh'):
            smoke.validate_approval(value, self.home)

    def test_package_link_cannot_escape(self):
        root = self.home / 'package'
        root.mkdir()
        (root / 'escape').symlink_to('/bin/sh')
        with self.assertRaisesRegex(smoke.Refused, 'escapes'):
            smoke.package_inventory(root)

    def test_ownership_requires_exact_membership_and_generations(self):
        owned = {'%1': dict(session='$3', title=pane()['title'], identity=[11, 100, 1])}
        rows = {'%1': pane(), '%80': pane(80, '@80', 'existing')}
        self.assertEqual(set(smoke.validate_owned(rows, '@9', owned, Kernel())), {'%1'})
        for changed in [dict(rows, **{'%2': pane(12)}), {}, {'%1': pane(12)}, {'%1': dict(pane(), name='other')}]:
            with self.subTest(changed=changed), self.assertRaises(smoke.Refused):
                smoke.validate_owned(changed, '@9', owned, Kernel())
        with patch.object(Kernel, 'identity', return_value=[11, 100, 2]):
            with self.assertRaisesRegex(smoke.Refused, 'identity'):
                smoke.validate_owned(rows, '@9', owned, Kernel())

    def test_missing_pane_can_only_be_skipped_during_cleanup(self):
        owned = {'%1': dict(session='$3', title=pane()['title'], identity=[11, 100, 1])}
        self.assertEqual(smoke.validate_owned({}, '@9', owned, Kernel(), True), {})
        with self.assertRaises(smoke.Refused):
            smoke.validate_owned({}, '@9', owned, Kernel())

    def test_inventory_rejects_ambiguous_dead_or_malformed_ids(self):
        good = b'$3|config(tmux-to-rust)|@9|owned|%1|11|0|sleep\n'
        self.assertEqual(smoke.parse_panes(good)['%1']['pid'], 11)
        for raw in [good + good, good.replace(b'|0|', b'|1|'), good.replace(b'%1', b'window-name'), b'unknown']:
            with self.subTest(raw=raw), self.assertRaises(smoke.Refused):
                smoke.parse_panes(raw)

    def test_native_launch_plan_requires_exact_supported_images(self):
        session = '12345678-1234-1234-1234-123456789abc'
        for key in ('claude296', 'claude299'):
            version, digest = smoke.PINS[key]
            with patch.object(smoke, 'digest', return_value=digest):
                command = smoke.native_launch_plan('claude', '/owned/' + version, session)
                self.assertEqual(command, ['/owned/' + version, '--session-id', session])
                with self.assertRaises(smoke.Refused):
                    smoke.native_launch_plan('claude', '/owned/2.1.300', session)
        with patch.object(smoke, 'digest', return_value=smoke.PINS['codex'][1]):
            command = smoke.native_launch_plan('codex', '/owned/codex')
            self.assertIn('--no-daemon', command)
            self.assertNotIn('--print', command)
        with patch.object(smoke, 'digest', return_value='0' * 64), self.assertRaises(smoke.Refused):
            smoke.native_launch_plan('claude', '/owned/2.1.300', session)

    def test_timeout_freezes_calls_without_signals_or_retry(self):
        calls = smoke.Calls(.001)
        with self.assertRaisesRegex(smoke.Refused, 'deadline'):
            calls.run([sys.executable, '-c', 'import time; time.sleep(.04)'])
        self.assertTrue(calls.frozen)
        child = calls.pending
        with patch.object(smoke.subprocess, 'Popen', side_effect=AssertionError('retry must not spawn')):
            with self.assertRaisesRegex(smoke.Refused, 'no further calls'):
                calls.run(['/must-not-run'])
        child.wait()
        child.stdout.close()
        child.stderr.close()

    def test_bounded_calls_preserve_stdout_stderr_and_exit(self):
        result = smoke.Calls().run([sys.executable, '-c', 'import sys; print(sys.stdin.read()); print("diagnostic",file=sys.stderr); sys.exit(6)'], b'payload')
        self.assertEqual((result.returncode, result.stdout, result.stderr), (6, b'payload\n', b'diagnostic\n'))

    def test_cleanup_is_atomic_and_refuses_unowned_pane(self):
        value = dict(root=str(self.home), server=[5, 100, 1])
        driver = smoke.Driver(value, calls=smoke.Calls(), kernel=Kernel())
        driver.window = '@9'
        driver.owned = {'%1': dict(session='$3', title=pane()['title'], identity=[11, 100, 1])}
        seen = []
        driver.command = lambda args: seen.append(args) or b's6x-mutation-refused'
        with self.assertRaisesRegex(smoke.Refused, 'atomic'):
            driver.mutation(['kill-window', '-t', '@9'], '%1', 1)
        args = seen[0]
        self.assertEqual(args[:4], ['if-shell', '-F', '-t', '%1'])
        self.assertIn('#{==:#{window_panes},1}', args[4])
        self.assertIn('#{==:#{pid},5}', args[4])
        self.assertIn('#{==:#{pane_pid},11}', args[4])
        self.assertEqual(shlex.split(args[5]), ['kill-window', '-t', '@9'])
        driver.panes = lambda: {'%1': pane(), '%2': pane(12)}
        driver.command = lambda args: self.fail('ownership refusal must precede cleanup mutation')
        with self.assertRaisesRegex(smoke.Refused, 'membership'):
            driver.cleanup()

    def test_no_approval_means_no_command(self):
        with patch.object(smoke.subprocess, 'Popen', side_effect=AssertionError('approval must precede every command')):
            with patch.object(sys, 'argv', ['smoke.py', '--approval', '/missing', '--approval-sha256', 'unreviewed', '--execute-refusal']):
                with self.assertRaises(smoke.Refused):
                    smoke.main()

    def test_refusal_proof_requires_no_input_and_exact_peer(self):
        peer = dict(session=3, window=9, pane=2, server_generation=100000001, pane_generation=100000001,
                    socket_device=7, socket_inode=8)
        announcement = dict(attempt='a' * 32, archive='b' * 32, state='terminal-no-input',
                            submission='unproved', receipt='unproved', peer=peer)
        ledger = dict(attempts=[dict(id=announcement['attempt'], archive=announcement['archive'], peer=peer,
                                     history=[dict(state='pending-no-input'), dict(state='terminal-no-input')])])
        sent = dict(exit=1, stdout=json.dumps(announcement))
        self.assertEqual(smoke.refusal_proof(sent, ledger, peer), announcement)
        for change in [dict(receipt='proved'), dict(submission='proved'), dict(state='submitted'), dict(peer=dict(peer, pane=99))]:
            with self.subTest(change=change), self.assertRaises(smoke.Refused):
                smoke.refusal_proof(dict(sent, stdout=json.dumps(dict(announcement, **change))), ledger, peer)
        with self.assertRaises(smoke.Refused):
            smoke.refusal_proof(dict(sent, exit=6), ledger, peer)
        ledger['attempts'][0]['history'].insert(1, dict(state='input-intent'))
        with self.assertRaises(smoke.Refused):
            smoke.refusal_proof(sent, ledger, peer)

    def orchestration(self, wrong_peer=False):
        value = self.approval()
        calls = smoke.Calls()
        calls.run = lambda argv: smoke.subprocess.CompletedProcess(argv, 0, b'help\n', b'')
        driver = smoke.Driver(value, calls=calls, kernel=Kernel())
        rows = {'%99': pane(99, '@80', 'existing')}
        mutations = []
        def command(args):
            if args[0] == 'list-panes':
                return ''.join('|'.join([p['session'], p['name'], p['window'], p['title'], key, str(p['pid']), '0', p['command']]) + '\n' for key, p in rows.items()).encode()
            if args[0] == 'if-shell':
                count = sum(p['window'] == '@9' for p in rows.values())
                self.assertIn('#{==:#{window_panes},' + str(count) + '}', args[4])
                self.assertIn(args[3], driver.owned)
                return command(shlex.split(args[5]))
            if args[0] in ('new-window', 'split-window'):
                number = len(driver.owned) + 1
                key = '%' + str(number)
                rows[key] = pane(number + 10)
                mutations.append((args[0], key))
                return ('@9|' + key + '\n').encode()
            if args[0] == 'display-message':
                self.assertIn(args[3], driver.owned)
                return b'0|0|215|57|0|0\n'
            if args[0] == 'capture-pane':
                self.assertIn(args[-1], driver.owned)
                return b'\n' * 57
            if args[0] == 'kill-pane':
                self.assertIn(args[-1], driver.owned)
                mutations.append(('kill-pane', args[-1]))
                del rows[args[-1]]
                return b''
            if args[0] == 'kill-window':
                self.assertEqual(args[-1], '@9')
                self.assertEqual(sum(p['window'] == '@9' for p in rows.values()), 1)
                mutations.append(('kill-window', args[-1]))
                rows.pop('%1')
                return b''
            self.fail('unexpected command ' + repr(args))
        driver.command = command
        def publish(_):
            request_path = driver.root / 'request.json'
            if not request_path.exists():
                return
            request = json.loads(request_path.read_bytes())
            peer = dict(session=3, window=9, pane=99 if wrong_peer else int(request['target'][1:]),
                        socket_device=7, socket_inode=8, server_generation=100000001, pane_generation=100000001)
            announcement = dict(attempt='a' * 32, archive='b' * 32, state='terminal-no-input', submission='unproved', receipt='unproved', peer=peer)
            ledger = dict(attempts=[dict(id=announcement['attempt'], archive=announcement['archive'], peer=peer,
                                         history=[dict(state='pending-no-input'), dict(state='terminal-no-input')])])
            smoke.atomic_json(Path(value['store']) / 'ledger.json', ledger)
            smoke.atomic_json(driver.root / 'sender-result.json', dict(closed=True, exit=1, stdout=json.dumps(announcement)))
        return driver, rows, mutations, publish

    def test_full_refusal_orchestration_retires_only_owned_window(self):
        driver, rows, mutations, publish = self.orchestration()
        with patch.object(smoke.time, 'sleep', side_effect=publish):
            result = driver.run()
        self.assertTrue(result['success'] and result['cleanup_proven'])
        self.assertEqual(rows, {'%99': pane(99, '@80', 'existing')})
        self.assertEqual([verb for verb, _ in mutations].count('new-window'), 1)
        self.assertEqual(mutations[-1], ('kill-window', '@9'))

    def test_full_refusal_peer_mismatch_freezes_before_cleanup(self):
        driver, rows, mutations, publish = self.orchestration(True)
        with patch.object(smoke.time, 'sleep', side_effect=publish), self.assertRaisesRegex(smoke.Refused, 'peer identity'):
            driver.run()
        self.assertTrue(driver.calls.frozen)
        self.assertFalse(any(verb.startswith('kill-') for verb, _ in mutations))
        self.assertIn('%99', rows)
        self.assertFalse(json.loads((driver.root / 'result.json').read_bytes())['cleanup_proven'])


if __name__ == '__main__':
    unittest.main()
