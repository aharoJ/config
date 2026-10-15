import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest

CUTOVER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(CUTOVER))
import package

PROBE = """import json, os, sys
print(json.dumps(dict(argv=sys.argv[1:], stdin=sys.stdin.read(), tool=__file__, env={key: os.environ.get(key) for key in ['ANGELSTAR_RELAY_STORE', 'ANGELSTAR_RELAY_SOCKET', 'CC_MSG_INBOX_ROOT', 'CC_MSG_SESSION', 'CODEX_SEND_SESSION', 'TMUX']})))
sys.exit(int(os.environ.get('PROBE_STATUS', '0')))
"""
CARGO = """#!/usr/bin/python3
import os, pathlib, sys
if '--version' in sys.argv:
    print('test-cargo 1')
else:
    manifest = pathlib.Path(sys.argv[sys.argv.index('--manifest-path') + 1])
    assert manifest.exists() and manifest.is_absolute()
    assert manifest.parents[3].name.startswith('rust-')
    assert (manifest.parent / '../tests/delivery_guard.py').resolve().is_file()
    target = pathlib.Path(os.environ['CARGO_TARGET_DIR']) / 'release/angelstar-runtime'
    target.parent.mkdir()
    target.write_text('#!/usr/bin/python3\\nprint("fake-runtime")\\n')
    target.chmod(0o700)
"""


def command(*arguments, cwd=None):
    return subprocess.check_output(arguments, cwd=cwd, stderr=subprocess.PIPE).decode().strip()


class Fixture(unittest.TestCase):
    def setUp(self):
        temporary = Path.home() / 'desk/tmp'
        temporary.mkdir(exist_ok=True)
        self.scratch = tempfile.TemporaryDirectory(prefix='s6x-package-test-', dir=temporary)
        self.root = Path(self.scratch.name).resolve()
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        command('git', 'init', '-q', str(self.repo))
        command('git', 'config', 'user.email', 'fixture@example.invalid', cwd=self.repo)
        command('git', 'config', 'user.name', 'Fixture', cwd=self.repo)
        self.put('tmux/tools/relay-core', 'baseline-only\n')
        for wrapper in package.SURFACES.values():
            self.put('tmux/tools/' + wrapper, PROBE, 0o755)
        command('git', 'add', '.', cwd=self.repo)
        command('git', 'commit', '-qm', 'baseline', cwd=self.repo)
        self.base_commit = command('git', 'rev-parse', 'HEAD', cwd=self.repo)
        self.put('tmux/rust/Cargo.toml', '[package]\nname="fixture"\nversion="0.1.0"\n')
        self.put('tmux/rust/Cargo.lock', 'fixture-lock\n')
        self.put('tmux/rust/src/main.rs', 'fn main() {}\n')
        self.put('tmux/tests/delivery_guard.py', 'import cleanup_guard\n')
        self.put('tmux/tests/cleanup_guard.py', 'dependency = "../tools/test-server-cleanup"\n')
        self.put('tmux/tools/test-server-cleanup', 'fixture-cleanup\n', 0o755)
        self.put('tmux/cutover/launch.py', (CUTOVER / 'launch.py').read_text())
        command('git', 'add', '.', cwd=self.repo)
        command('git', 'commit', '-qm', 'candidate', cwd=self.repo)
        self.commit = command('git', 'rev-parse', 'HEAD', cwd=self.repo)
        self.packages = self.root / 'packages'
        self.baseline_repo = self.root / 'stable'
        command('git', 'clone', '--quiet', '--shared', str(self.repo), str(self.baseline_repo))
        command('git', 'checkout', '-q', self.base_commit, cwd=self.baseline_repo)
        snapshot = package.working_tree_snapshot(self.baseline_repo, self.base_commit)[1]
        self.baseline = self.packages / ('python-' + self.base_commit + '-' + snapshot['sha256'])
        self.candidate = self.packages / ('rust-' + self.commit)
        self.store = self.root / 'store'
        self.inbox = self.root / 'inbox'
        self.socket = str(self.root / 'socket')
        self.toolchain = self.root / 'toolchain'
        self.toolchain.mkdir()
        (self.toolchain / 'cargo').write_text(CARGO)
        (self.toolchain / 'cargo').chmod(0o700)
        (self.toolchain / 'rustc').write_text('#!/bin/sh\necho test-rustc-1\n')
        (self.toolchain / 'rustc').chmod(0o700)
        dispatcher = (CUTOVER / 'launch.py').read_bytes()
        self.base_hash = package.build_package(self.baseline_repo, self.base_commit, self.baseline, 'python-v1', dispatcher, self.store, self.inbox, self.socket, os.geteuid())
        self.candidate_hash = package.build_package(self.repo, self.commit, self.candidate, 'rust-v1', dispatcher, self.store, self.inbox, self.socket, os.geteuid(), self.toolchain, self.root / 'build', self.root / 'cache')

    def put(self, relative, text, mode=0o644):
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        path.chmod(mode)

    def tearDown(self):
        for current, directories, files in os.walk(self.root):
            Path(current).chmod(0o700)
            for name in files:
                path = Path(current) / name
                if not path.is_symlink():
                    path.chmod(0o600)
        self.scratch.cleanup()

    def invoke(self, root, surface, arguments=(), data=b'', extra=None):
        environment = {key: value for key, value in os.environ.items() if not key.startswith(('ANGELSTAR_', 'CC_MSG_', 'CODEX_SEND_', 'TMUX'))}
        environment.update(extra or {})
        return subprocess.run([str(root / 'bin' / surface), *arguments], input=data, capture_output=True, env=environment)


class PackageTests(Fixture):
    def test_dispatch_all_surfaces_argv_stdin_status_read_and_exit(self):
        for root in (self.baseline, self.candidate):
            for surface, wrapper in package.SURFACES.items():
                result = self.invoke(root, surface, ['status', 'attempt-x', 'read', 'wire', 'a;b', '$literal'], b'exact\x00stdin\n', {'PROBE_STATUS': '6', 'CC_MSG_SESSION': 'explicit-cc', 'CODEX_SEND_SESSION': 'explicit-codex'})
                self.assertEqual(result.returncode, 6, result.stderr)
                value = json.loads(result.stdout)
                self.assertEqual(value['argv'], ['status', 'attempt-x', 'read', 'wire', 'a;b', '$literal'])
                self.assertEqual(value['stdin'], 'exact\x00stdin\n')
                self.assertEqual(value['tool'], str(root / 'src/tmux/tools' / wrapper))
                self.assertEqual(value['env']['ANGELSTAR_RELAY_SOCKET'], self.socket)
                self.assertEqual(value['env']['CC_MSG_SESSION'], 'explicit-cc')
                self.assertEqual(value['env']['CODEX_SEND_SESSION'], 'explicit-codex')
                if root == self.baseline:
                    self.assertEqual(value['env']['CC_MSG_INBOX_ROOT'], str(self.inbox))
                    self.assertEqual(value['env']['TMUX'], self.socket + ',0,0')
                else:
                    self.assertEqual(value['env']['ANGELSTAR_RELAY_STORE'], str(self.store))

    def test_matching_and_conflicting_environment(self):
        self.assertEqual(self.invoke(self.candidate, 'relay', extra={'ANGELSTAR_RELAY_STORE': str(self.store), 'ANGELSTAR_RELAY_SOCKET': self.socket}).returncode, 0)
        cases = [(self.candidate, {'ANGELSTAR_RELAY_STORE': '/wrong'}), (self.candidate, {'ANGELSTAR_RELAY_SOCKET': '/wrong'}), (self.baseline, {'CC_MSG_INBOX_ROOT': '/wrong'}), (self.baseline, {'TMUX': '/wrong,1,2'}), (self.baseline, {'TMUX_BIN': '/wrong'}), (self.baseline, {'TMUX_LAB_RECORD': '1'}), (self.baseline, {'ANGELSTAR_RELAY_STORE': str(self.store)})]
        for root, environment in cases:
            result = self.invoke(root, 'cc-msg', extra=environment)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, b'')
        good = self.invoke(self.baseline, 'relay', extra={'TMUX': self.socket + ',999,7', 'CC_MSG_INBOX_ROOT': str(self.inbox)})
        self.assertEqual(json.loads(good.stdout)['env']['TMUX'], self.socket + ',999,7')

    def test_manifest_exact_sources_helpers_and_frozen_inventory(self):
        manifest, actual = package.verify_package(self.candidate, self.candidate_hash)
        self.assertEqual(actual, self.candidate_hash)
        names = {entry['path'] for entry in manifest['sources']}
        self.assertIn('tmux/tests/delivery_guard.py', names)
        self.assertIn('tmux/tests/cleanup_guard.py', names)
        self.assertIn('tmux/tools/test-server-cleanup', names)
        self.assertEqual(names, {entry['path'] for entry in package.source_tree(self.repo, self.commit, package.RUST_PATHS)})
        self.assertEqual({entry['path'] for entry in package.verify_package(self.baseline)[0]['sources']}, {entry['path'] for entry in package.source_tree(self.repo, self.base_commit, ['tmux/tools'])})
        for root in (self.baseline, self.candidate):
            self.assertEqual(stat.S_IMODE(root.stat().st_mode), 0o500)
            for name in package.SURFACES:
                self.assertEqual((root / 'bin' / name).resolve(), root / 'launch')
            config = json.loads((root / 'transport.json').read_bytes())
            self.assertEqual(config['package'], str(root))
            self.assertEqual(config['send'], str(root / 'bin/cc-msg'))
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            package.verify_package(self.candidate, '0' * 64)

    def test_changed_file_symlink_or_mode_refuses(self):
        launch = self.candidate / 'launch'
        launch.chmod(0o700)
        with self.assertRaises(ValueError):
            package.verify_package(self.candidate)
        launch.chmod(0o500)
        binary = self.candidate / 'src/tmux/tools/angelstar-runtime'
        binary.chmod(0o700)
        binary.write_bytes(b'changed')
        binary.chmod(0o500)
        with self.assertRaisesRegex(ValueError, 'inventory'):
            package.verify_package(self.candidate)
        entry = self.baseline / 'bin/relay'
        entry.parent.chmod(0o700)
        entry.unlink()
        entry.symlink_to('/usr/bin/true')
        entry.parent.chmod(0o500)
        with self.assertRaises(ValueError):
            package.verify_package(self.baseline)

    def test_existing_package_uid_and_nonfinalpath_refused_before_writes(self):
        with self.assertRaises(ValueError):
            package.build_package(self.repo, self.commit, self.candidate, 'rust-v1', b'', self.store, self.inbox, self.socket, os.geteuid())
        wrong = self.packages / 'staging'
        with self.assertRaisesRegex(ValueError, 'final package'):
            package.build_package(self.repo, self.commit, wrong, 'rust-v1', b'', self.store, self.inbox, self.socket, os.geteuid())
        self.assertFalse(wrong.exists())
        unknown = self.packages / ('python-' + '0' * 40)
        with self.assertRaises(ValueError):
            package.build_package(self.repo, '0' * 40, unknown, 'python-v1', b'', self.store, self.inbox, self.socket, os.geteuid() + 1)
        self.assertFalse(unknown.exists())

    def test_working_baseline_preserves_dirty_bytes_and_modes(self):
        live = self.baseline_repo / 'tmux/tools/relay-core'
        live.write_bytes(b'foreign working baseline\n')
        live.chmod(0o740)
        snapshot = package.working_tree_snapshot(self.baseline_repo, self.base_commit)[1]
        self.assertIn('tmux/tools/relay-core', snapshot['dirty_inventory'])
        root = self.packages / ('python-' + self.base_commit + '-' + snapshot['sha256'])
        package.build_package(self.baseline_repo, self.base_commit, root, 'python-v1', (CUTOVER / 'launch.py').read_bytes(), self.store, self.inbox, self.socket, os.geteuid())
        manifest, _ = package.verify_package(root)
        self.assertEqual(manifest['working_tree']['sha256'], snapshot['sha256'])
        self.assertEqual((root / 'src/tmux/tools/relay-core').read_bytes(), live.read_bytes())
        self.assertEqual(stat.S_IMODE((root / 'src/tmux/tools/relay-core').stat().st_mode), 0o540)
        self.assertEqual(live.read_bytes(), b'foreign working baseline\n')
        self.assertEqual(stat.S_IMODE(live.stat().st_mode), 0o740)
        live.write_bytes(b'new drift\n')
        self.assertNotEqual(package.working_tree_snapshot(self.baseline_repo, self.base_commit)[1]['sha256'], snapshot['sha256'])


if __name__ == '__main__':
    unittest.main()
