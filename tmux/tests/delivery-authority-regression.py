#!/usr/bin/python3
import ast
import hashlib
import importlib.util
import marshal
import json
import struct
from pathlib import Path
import runpy
import shlex
import subprocess
import sys
import tempfile
import unittest

BASE = Path(__file__).resolve().parents[1]
guard = runpy.run_path(str(BASE / 'tests/delivery_guard.py'))


class Authority(unittest.TestCase):
    def test_external_launch_pin_refuses_changes(self):
        controller = BASE / 'tests/fixtures/window-native-e2e.py'
        live = runpy.run_path(str(controller))
        # Successful verification uses the isolated manifest below. A consumed
        # live review pin must keep refusing later publication edits.
        with self.assertRaisesRegex(RuntimeError, 'source manifest changed'):
            live['verify_source_pin']('0' * 64)
        with tempfile.TemporaryDirectory(prefix='k58-pin-', dir=Path.home() / 'desk/tmp') as name:
            root = Path(name)
            rejected_root = root / 'must-not-create'
            rejected = subprocess.run([sys.executable, str(controller), '--mode', 'codex-startup', '--pin', '0' * 64,
                                       '/must-not-execute', str(rejected_root)], capture_output=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn(b'reviewed source manifest changed', rejected.stderr)
            self.assertFalse(rejected_root.exists())
            copy = root / controller.name
            copy.write_bytes(controller.read_bytes())
            helper = root / 'delivery_guard.py'
            helper.write_bytes((BASE / 'tests/delivery_guard.py').read_bytes())
            test = runpy.run_path(str(copy))
            manifest = root / 'source.txt'
            def inventory():
                return ''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + str(p) + '\n' for p in [copy, helper])
            manifest.write_text(inventory())
            test['verify_source_pin'].__globals__['SOURCE_MANIFEST'] = manifest
            approved_pin = hashlib.sha256(manifest.read_bytes()).hexdigest()
            test['verify_source_pin'](approved_pin)
            helper.write_bytes(helper.read_bytes() + b'\n# changed helper\n')
            copy.write_bytes(copy.read_bytes() + b'\n# changed controller\n')
            manifest.write_text(inventory())
            # Coupled controller/helper/manifest mutation cannot change Red's
            # externally supplied command-line pin.
            with self.assertRaisesRegex(RuntimeError, 'source manifest changed'):
                test['verify_source_pin'](approved_pin)

    def test_controller_oracles_ignore_altered_timestamp_valid_cache(self):
        controller = runpy.run_path(str(BASE / 'tests/fixtures/window-native-e2e.py'))
        source = (BASE / 'tests/fixtures/keeper_oracles.py').read_bytes()
        with tempfile.TemporaryDirectory(prefix='k64-cache-') as name:
            path = Path(name) / 'keeper_oracles.py'
            path.write_bytes(source)
            # Explicit cache path avoids modifying the host's configured cache
            # prefix. The timestamp/size header matches the real helper source.
            cache = path.parent / '__pycache__' / ('keeper_oracles.' + sys.implementation.cache_tag + '.pyc')
            cache.parent.mkdir()
            stat = path.stat()
            poison = compile("UUID = 'unreviewed-cache'", str(path), 'exec')
            header = importlib.util.MAGIC_NUMBER + struct.pack('<III', 0, int(stat.st_mtime), stat.st_size)
            cache.write_bytes(header + marshal.dumps(poison))
            # Prove this is a valid executable poisoned cache, not junk bytes.
            spec = importlib.util.spec_from_file_location('_poisoned_keeper_test', cache)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            self.assertEqual(module.UUID, 'unreviewed-cache')
            loaded = controller['load_oracles'](path)
            self.assertEqual(loaded[0], runpy.run_path(str(path))['UUID'])
            self.assertNotEqual(loaded[0], module.UUID)
            self.assertTrue(loaded[3]([b'exact'], b'exact'))

    def test_stage_b_requires_separate_exact_post_evidence_review(self):
        controller = BASE / 'tests/fixtures/window-native-e2e.py'
        live = runpy.run_path(str(controller))
        pin = hashlib.sha256(live['SOURCE_MANIFEST'].read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory(prefix='k69-stage-gate-') as name:
            root = Path(name)
            result = root / 'stage-a.json'
            review = root / 'red.md'
            data = dict(mode='codex-startup', source_pin=pin, error=None,
                        readiness_proven=True, cleanup_proven=True,
                        completed=[['codex', 'startup']], runtime_sha256=live['EXPECTED_RUNTIME'],
                        probe_sha256=live['EXPECTED_PROBE'])
            result.write_text(json.dumps(data))
            with self.assertRaisesRegex(RuntimeError, 'requires successful Stage A'):
                live['verify_stage_b'](pin, result, None)
            review.write_text('Stage A received; review pending\n')
            with self.assertRaisesRegex(RuntimeError, 'clearance missing'):
                live['verify_stage_b'](pin, result, review)
            marker = 'K69_STAGE_B_CLEARANCE ' + pin + ' ' + hashlib.sha256(result.read_bytes()).hexdigest()
            review.write_text(marker + '\n')
            live['verify_stage_b'](pin, result, review)
            data['cleanup_proven'] = False
            result.write_text(json.dumps(data))
            with self.assertRaisesRegex(RuntimeError, 'not successful'):
                live['verify_stage_b'](pin, result, review)

    def test_failed_external_preflight_never_reaches_launch(self):
        source = (BASE / 'tests/fixtures/k70-codex-keepers.sh').read_text()
        with tempfile.TemporaryDirectory(prefix='k70-chain-') as name:
            root = Path(name)
            sentinel = root / 'controller-was-launched'
            # Replace only the real launch command with a harmless sentinel;
            # preserve the exact preflight and its shell chain under test.
            start = source.index('exec /usr/bin/python3 -B ')
            copy = root / 'launcher.sh'
            copy.write_text(source[:start] + 'exec /usr/bin/touch ' + shlex.quote(str(sentinel)) + '\n')
            rejected = subprocess.run(['/bin/sh', str(copy), '0' * 64], capture_output=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn(b'external launch-manifest pin mismatch', rejected.stderr)
            self.assertFalse(sentinel.exists())

    def test_exact_accepted_stage_a_survives_new_launch_pin(self):
        live = runpy.run_path(str(BASE / 'tests/fixtures/window-native-e2e.py'))
        pin = hashlib.sha256(live['SOURCE_MANIFEST'].read_bytes()).hexdigest()
        original = Path.home() / 'desk/tmp/k69-codex-startup-20261014/result.json'
        data = original.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), live['ACCEPTED_STAGE_A_RESULT'])
        with tempfile.TemporaryDirectory(prefix='k70-original-a-') as name:
            root = Path(name)
            result, review = root / 'a.json', root / 'red.md'
            result.write_bytes(data)
            marker = 'K69_STAGE_B_CLEARANCE ' + pin + ' ' + hashlib.sha256(data).hexdigest()
            review.write_text(marker + '\n')
            live['verify_stage_b'](pin, result, review)
            # Even a semantics-preserving change loses the historical exception.
            result.write_bytes(data + b'\n')
            with self.assertRaisesRegex(RuntimeError, 'not successful'):
                live['verify_stage_b'](pin, result, review)

    def test_exception_details_keep_reason_and_sanitized_missing_path(self):
        live = runpy.run_path(str(BASE / 'tests/fixtures/window-native-e2e.py'))
        missing = FileNotFoundError(2, 'No such file or directory', str(Path.home() / '.codex/state_5.sqlite'))
        detail = live['exception_details'](missing)
        self.assertEqual(detail['exception_type'], 'FileNotFoundError')
        self.assertEqual(detail['message'], 'No such file or directory')
        self.assertEqual(detail['missing_path'], '$HOME/.codex/state_5.sqlite')
        error = json.JSONDecodeError('Expecting value', 'unretained native text', 0)
        detail = live['exception_details'](error)
        self.assertNotIn('unretained native text', json.dumps(detail))
        self.assertIn('Expecting value', detail['message'])
        with self.assertRaisesRegex(RuntimeError, 'requires passing'):
            live['verify_private_dryrun']('0' * 64, None)

    def test_delivery_cannot_destroy_or_signal(self):
        validate = guard['validate']
        validate(['list-panes', '-a', '-F', '#{pane_id}'])
        paste = 'paste-buffer -b relay-' + 'a' * 32 + ' -t %123 ; display-message -p applied'
        validate(['if-shell', '-F', '-t', '%123', '#{pane_active}', paste, 'display-message -p refused'])
        for bad in ['kill-server', 'kill-session -t config', 'kill-pane -t %123',
                    'run-shell "kill -9 123"', 'send-keys -t %123 C-c',
                    'display-message -p "#(kill -9 123)"',
                    'display-message -p applied ; kill-server',
                    'display-message -p "#{E:@untrusted}"',
                    'display-message -p "#{T:@untrusted}"',
                    "if-shell -F -t %123 1 'kill-session' 'display-message -p refused'"]:
            with self.subTest(command=bad):
                with self.assertRaises(ValueError):
                    validate(shlex.split(bad))
                with self.assertRaises(ValueError):
                    validate(['if-shell', '-F', '-t', '%123', '1', bad, 'display-message -p refused'])
        # Production Rust has no API that sends a process signal. libc::signal
        # installs receipt handlers; it does not send a signal.
        for source in (BASE / 'rust/src').glob('*.rs'):
            text = source.read_text()
            for forbidden in ['.kill(', 'libc::kill(', 'libc::raise(', 'killpg(', 'pthread_kill(']:
                self.assertNotIn(forbidden, text, str(source))
        tree = ast.parse((BASE / 'tests/delivery_guard.py').read_text())
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                self.assertNotIn(node.func.attr, ['kill', 'killpg', 'send_signal', 'terminate'])
                if node.func.attr == 'run':
                    self.assertNotIn('timeout', [arg.arg for arg in node.keywords])


if __name__ == '__main__':
    unittest.main()
