import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import unittest
from unittest.mock import patch

from test_package import CUTOVER, Fixture, command
import install
import package


class InstallTests(Fixture):
    def setUp(self):
        super().setUp()
        self.stable = self.baseline_repo
        self.baseline_pin = patch.object(install, 'BASELINE', self.base_commit)
        self.baseline_pin.start()
        self.home = self.root / 'home'
        for relative in ('.local/bin', '.local/share', '.config'):
            (self.home / relative).mkdir(parents=True, exist_ok=True)
        for surface, wrapper in package.SURFACES.items():
            path = self.home / '.local/bin' / surface
            path.symlink_to(self.stable / 'tmux/tools' / wrapper)
            if hasattr(os, 'lchmod'):
                os.lchmod(path, 0o755)
        self.caller = self.home / '.config/caller'
        self.caller.write_bytes(b'before\n')
        self.caller.chmod(0o640)
        self.staged = self.root / 'staged'
        self.staged.write_bytes(b'after dual-compatible\n')
        self.migration = self.root / 'migration.json'
        self.entries = [self.entry(self.caller)]
        self.transaction = self.root / 'transaction'
        self.pointer = self.home / '.local/share/relay-current'
        self.hash = None

    def tearDown(self):
        self.baseline_pin.stop()
        super().tearDown()

    def entry(self, path, staged=None):
        staged = staged or self.staged
        return dict(path=str(path), beforehash=package.digest(path.read_bytes()), stagedpath=str(staged), afterhash=package.digest(staged.read_bytes()), reason='fixture dual transport caller')

    def prepare(self):
        self.migration.write_bytes(package.json_bytes(dict(schema='relay-caller-migration', version=1, entries=self.entries)))
        self.hash = install.prepare(self.migration, self.baseline, self.candidate, self.transaction, self.home, self.stable)
        return self.hash

    def activate(self, resume=False):
        with patch.object(install, 'verify_drain', return_value={}):
            return install.activate(self.transaction, self.hash, self.root / 'drain.json', '0' * 64, resume)

    def snapshot(self):
        return dict(pointer=os.readlink(self.pointer) if self.pointer.is_symlink() else None, links={name: os.readlink(self.home / '.local/bin' / name) for name in package.SURFACES}, caller=self.caller.read_bytes(), journal=(self.transaction / 'journal.jsonl').read_bytes() if self.transaction.exists() else None)

    def test_prepare_and_check_readonly_all_payloads(self):
        before = self.snapshot()
        self.prepare()
        self.assertFalse(os.path.lexists(self.pointer))
        self.assertEqual(self.caller.read_bytes(), b'before\n')
        self.assertEqual(self.snapshot()['links'], before['links'])
        prepared = self.snapshot()
        install.check(self.transaction, self.hash)
        self.assertEqual(self.snapshot(), prepared)
        for mode in ('--check', '--dry-run'):
            result = subprocess.run([sys.executable, '-B', str(CUTOVER / 'install.py'), mode, '--transaction', str(self.transaction), '--prepared-hash', self.hash], capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn(b'fresh drain', result.stderr)
            self.assertEqual(self.snapshot(), prepared)

    def test_activation_and_one_command_rollback_all_four(self):
        self.prepare()
        self.activate()
        self.assertEqual(os.readlink(self.pointer), str(self.candidate))
        self.assertEqual(self.caller.read_bytes(), self.staged.read_bytes())
        self.assertEqual(stat.S_IMODE(self.caller.stat().st_mode), 0o640)
        for surface in package.SURFACES:
            self.assertEqual((self.home / '.local/bin' / surface).resolve(), self.candidate / 'launch')
            self.assertEqual(stat.S_IMODE((self.home / '.local/bin' / surface).lstat().st_mode), 0o755 if hasattr(os, 'lchmod') else 0o777)
        result = subprocess.run([sys.executable, '-B', str(CUTOVER / 'install.py'), '--rollback', '--transaction', str(self.transaction), '--prepared-hash', self.hash], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.readlink(self.pointer), str(self.baseline))
        for surface in package.SURFACES:
            self.assertEqual((self.home / '.local/bin' / surface).resolve(), self.baseline / 'launch')
            self.assertEqual(stat.S_IMODE((self.home / '.local/bin' / surface).lstat().st_mode), 0o755 if hasattr(os, 'lchmod') else 0o777)
        self.assertEqual(self.caller.read_bytes(), self.staged.read_bytes())
        self.assertTrue(self.candidate.exists())

    def test_rollback_wrong_missing_regular_relative_pointer_no_mutation(self):
        self.prepare()
        cases = ['missing', 'regular', str(self.baseline), os.path.relpath(self.candidate, self.pointer.parent), str(self.root / 'unexpected')]
        for target in cases:
            if os.path.lexists(self.pointer):
                self.pointer.unlink()
            if target == 'regular':
                self.pointer.write_text('untouched')
            elif target != 'missing':
                self.pointer.symlink_to(target)
                if hasattr(os, 'lchmod'):
                    os.lchmod(self.pointer, 0o777)
            before = sorted(path.name for path in self.pointer.parent.iterdir())
            journal = (self.transaction / 'journal.jsonl').read_bytes()
            with self.assertRaises(ValueError):
                install.rollback(self.transaction, self.hash)
            self.assertEqual(sorted(path.name for path in self.pointer.parent.iterdir()), before)
            self.assertEqual((self.transaction / 'journal.jsonl').read_bytes(), journal)
            if target == 'regular':
                self.assertEqual(self.pointer.read_text(), 'untouched')
            elif target != 'missing':
                self.assertEqual(os.readlink(self.pointer), target)

    def test_changed_before_after_package_or_link_refuses_before_mutation(self):
        self.prepare()
        self.caller.write_bytes(b'unexpected')
        before = self.snapshot()
        with self.assertRaises(ValueError):
            self.activate()
        self.assertEqual(self.snapshot(), before)
        self.caller.write_bytes(b'before\n')
        prepared = self.transaction / '0000.after'
        prepared.chmod(0o600)
        prepared.write_bytes(b'bad')
        prepared.chmod(0o400)
        before = self.snapshot()
        with self.assertRaises(ValueError):
            self.activate()
        self.assertEqual(self.snapshot(), before)

    def test_package_or_public_link_or_caller_mode_change_refuses(self):
        self.prepare()
        self.caller.chmod(0o600)
        before = self.snapshot()
        with self.assertRaises(ValueError):
            self.activate()
        self.assertEqual(self.snapshot(), before)
        self.caller.chmod(0o640)
        public = self.home / '.local/bin/cc-msg'
        public.unlink()
        public.symlink_to(self.stable / 'tmux/tools/relay')
        before = self.snapshot()
        with self.assertRaises(ValueError):
            self.activate()
        self.assertEqual(self.snapshot(), before)
        public.unlink()
        public.symlink_to(self.stable / 'tmux/tools/cc-msg.sh')
        launch = self.candidate / 'launch'
        launch.chmod(0o700)
        before = self.snapshot()
        with self.assertRaises(ValueError):
            self.activate()
        self.assertEqual(self.snapshot(), before)

    def test_partial_enrollment_stays_python_and_recovers(self):
        self.prepare()
        original = install.atomic_link
        calls = []
        def fail_third(path, target, expected):
            calls.append(str(path))
            if len(calls) == 3:
                raise OSError('injected enrollment failure')
            return original(path, target, expected)
        with patch.object(install, 'atomic_link', side_effect=fail_third):
            with self.assertRaisesRegex(OSError, 'injected'):
                self.activate()
        self.assertEqual(os.readlink(self.pointer), str(self.baseline))
        for surface, wrapper in package.SURFACES.items():
            resolved = (self.home / '.local/bin' / surface).resolve()
            self.assertIn(resolved, (self.baseline / 'launch', self.stable / 'tmux/tools' / wrapper))
        self.assertEqual(self.caller.read_bytes(), b'before\n')
        self.assertIn(b'activation-stopped', (self.transaction / 'journal.jsonl').read_bytes())
        self.activate(resume=True)
        self.assertEqual(os.readlink(self.pointer), str(self.candidate))

    def test_migration_failure_keeps_python_and_backups_then_resume(self):
        second = self.home / '.config/second'
        second.write_bytes(b'before\n')
        second.chmod(0o640)
        self.entries.append(self.entry(second))
        self.prepare()
        original = install.os.replace
        def fail_second(source, destination):
            if Path(destination) == second:
                raise OSError('injected caller failure')
            return original(source, destination)
        with patch.object(install.os, 'replace', side_effect=fail_second):
            with self.assertRaisesRegex(OSError, 'injected caller'):
                self.activate()
        self.assertEqual(os.readlink(self.pointer), str(self.baseline))
        self.assertEqual(self.caller.read_bytes(), self.staged.read_bytes())
        self.assertEqual(second.read_bytes(), b'before\n')
        self.assertEqual((self.transaction / '0000.before').read_bytes(), b'before\n')
        self.activate(resume=True)
        self.assertEqual(second.read_bytes(), self.staged.read_bytes())
        self.assertEqual(os.readlink(self.pointer), str(self.candidate))

    def test_aliases_hardlinks_modes_preserved(self):
        alias = self.home / '.config/alias'
        alias.symlink_to('caller')
        hardlink = self.home / '.config/hardlink'
        os.link(self.caller, hardlink)
        self.entries += [self.entry(alias), self.entry(hardlink)]
        self.prepare()
        self.activate()
        self.assertEqual(os.readlink(alias), 'caller')
        self.assertEqual(self.caller.stat().st_ino, hardlink.stat().st_ino)
        self.assertEqual(self.caller.stat().st_nlink, 2)
        self.assertEqual(stat.S_IMODE(hardlink.stat().st_mode), 0o640)
        self.assertEqual(alias.read_bytes(), self.staged.read_bytes())
        install.rollback(self.transaction, self.hash)
        self.assertEqual(self.caller.stat().st_ino, hardlink.stat().st_ino)

    def test_collision_undiscovered_hardlink_and_alias_change_refuse(self):
        wrong = self.root / 'wrong-staged'
        wrong.write_bytes(b'different after')
        self.entries.append(self.entry(self.caller, wrong))
        with self.assertRaisesRegex(ValueError, 'collision'):
            self.prepare()
        self.assertFalse(self.transaction.exists())
        self.entries.pop()
        hardlink = self.home / '.config/unlisted'
        os.link(self.caller, hardlink)
        with self.assertRaisesRegex(ValueError, 'undiscovered hardlink'):
            self.prepare()
        self.assertFalse(self.transaction.exists())
        hardlink.unlink()
        alias = self.home / '.config/alias'
        alias.symlink_to('caller')
        self.entries = [self.entry(alias)]
        self.prepare()
        alias.unlink()
        alias.symlink_to('unlisted')
        before = self.snapshot()
        with self.assertRaises((ValueError, FileNotFoundError)):
            self.activate()
        self.assertEqual(self.snapshot(), before)

    def test_stable_drift_and_prepared_pin_refuse(self):
        (self.stable / 'tmux/tools/relay-core').write_text('changed baseline')
        with self.assertRaisesRegex(ValueError, 'stable checkout drift'):
            self.prepare()
        self.assertFalse(self.transaction.exists())
        command('git', 'restore', 'tmux/tools/relay-core', cwd=self.stable)
        self.prepare()
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, 'prepared manifest hash'):
            install.activate(self.transaction, '0' * 64, self.root / 'drain', '0' * 64)
        self.assertEqual(self.snapshot(), before)

    def test_new_caller_absent_until_activation_and_retained_after_rollback(self):
        new = self.home / '.config/relay.mjs'
        entry = self.entry(self.caller)
        entry.update(path=str(new), beforehash=None)
        self.entries.append(entry)
        self.prepare()
        self.assertFalse(os.path.lexists(new))
        plan = install.check(self.transaction, self.hash)
        new_entry = next(row for row in plan['callers'] if row['destination'] == str(new))
        self.assertIsNone(new_entry['backup'])
        self.activate()
        self.assertEqual(new.read_bytes(), self.staged.read_bytes())
        self.assertEqual(stat.S_IMODE(new.stat().st_mode), stat.S_IMODE(self.staged.stat().st_mode))
        install.rollback(self.transaction, self.hash)
        self.assertEqual(new.read_bytes(), self.staged.read_bytes())

    def test_new_caller_unexpected_existing_file_or_symlink_refuses(self):
        new = self.home / '.config/relay.mjs'
        entry = self.entry(self.caller)
        entry.update(path=str(new), beforehash=None)
        self.entries.append(entry)
        new.write_bytes(b'unexpected')
        with self.assertRaisesRegex(ValueError, 'unexpectedly exists'):
            self.prepare()
        self.assertFalse(self.transaction.exists())
        new.unlink()
        self.prepare()
        new.symlink_to('caller')
        before = self.snapshot()
        with self.assertRaises(ValueError):
            self.activate()
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(os.readlink(new), 'caller')

    def test_new_caller_creation_race_never_clobbers(self):
        new = self.home / '.config/relay.mjs'
        entry = self.entry(self.caller)
        entry.update(path=str(new), beforehash=None)
        self.entries = [entry]
        self.prepare()
        original = os.link
        def race(source, destination, **kwargs):
            if Path(destination) == new:
                new.write_bytes(b'concurrent owner data')
            return original(source, destination, **kwargs)
        with patch.object(install.os, 'link', side_effect=race):
            with self.assertRaises(FileExistsError):
                self.activate()
        self.assertEqual(new.read_bytes(), b'concurrent owner data')
        self.assertEqual(os.readlink(self.pointer), str(self.baseline))
        self.assertEqual(self.caller.read_bytes(), b'before\n')
        with self.assertRaises(ValueError):
            self.activate(resume=True)

    def test_initial_pointer_creation_never_clobbers_concurrent_path(self):
        self.prepare()
        original = os.link
        def race(source, destination, **kwargs):
            if Path(destination) == self.pointer:
                self.pointer.write_bytes(b'concurrent owner pointer')
            return original(source, destination, **kwargs)
        with patch.object(install.os, 'link', side_effect=race):
            with self.assertRaises(FileExistsError):
                self.activate()
        self.assertEqual(self.pointer.read_bytes(), b'concurrent owner pointer')
        for surface, wrapper in package.SURFACES.items():
            self.assertEqual(os.readlink(self.home / '.local/bin' / surface), str(self.stable / 'tmux/tools' / wrapper))
        self.assertEqual(self.caller.read_bytes(), b'before\n')

    def test_drain_blocked_wrong_scope_or_server_refuses_without_writes(self):
        self.prepare()
        plan = install.check(self.transaction, self.hash)
        report = self.root / 'drain.json'
        evidence = dict(schema='relay-drain-1', clear=True, socket=plan['socket'], roots=[plan['inbox']], rust=dict(path=plan['store']), checked_at=0, server_pid=12, server_generation='generation', socket_device=1, socket_inode=2)
        import drain
        for changes, fresh in ((dict(rust=dict(path='/wrong-store')), evidence), (dict(clear=False), evidence), ({}, dict(evidence, server_pid=13))):
            report.write_bytes(package.json_bytes(dict(evidence, **changes)))
            before = self.snapshot()
            with patch.object(drain, 'collect', return_value=fresh):
                with self.assertRaises(ValueError):
                    install.verify_drain(plan, report, package.digest(report.read_bytes()))
            self.assertEqual(self.snapshot(), before)
        report.write_bytes(package.json_bytes(evidence))
        with patch.object(drain, 'collect', return_value=evidence):
            install.verify_drain(plan, report, package.digest(report.read_bytes()))


if __name__ == '__main__':
    unittest.main()
