import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("cleanup_guard", Path(__file__).with_name("cleanup_guard.py"))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class CleanupTests(unittest.TestCase):
    def test_default_and_alias_refuse_before_any_backend(self):
        default = f"/private/tmp/tmux-{os.geteuid()}/default"
        with patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
            for path in (default, f"/tmp/tmux-{os.geteuid()}/default"):
                with self.assertRaises(guard.CleanupRefused):
                    guard.stop(path)
            with self.assertRaises(guard.CleanupRefused):
                guard.guarded_run(["tmux", "-L", "default", "kill-server"])

    def test_inherited_decoy_is_protected_before_any_backend(self):
        with tempfile.TemporaryDirectory(prefix="s7tk-decoy-", dir=Path.home() / "desk/tmp") as root:
            path = Path(root) / "decoy-server"
            with patch.dict(os.environ, {"TMUX": f"{path},123,0"}), patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
                with self.assertRaises(guard.CleanupRefused):
                    guard.stop(path)

    def test_missing_explicit_socket_or_record_refuses(self):
        with patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
            with self.assertRaises(guard.CleanupRefused):
                guard.guarded_run(["tmux", "kill-server"])
            with self.assertRaises(guard.CleanupRefused):
                guard.stop(Path.home() / "desk/tmp/not-a-created-s7tk-socket")

    def test_payload_word_is_not_a_cleanup_command(self):
        result = subprocess.CompletedProcess([], 0)
        with patch.object(guard, "route", return_value=Path(__file__).parent), patch.object(guard, "load", return_value={}), patch.object(guard, "observation_matches", return_value=True), patch.dict(os.environ, {"KS01_RUN_CAP": "test-delegation"}), patch.object(guard, "_run", return_value=result) as run:
            self.assertIs(guard.guarded_run(["tmux", "-L", "private", "send-keys", "-l", "kill-server"]), result)
            run.assert_called_once()

    def test_directory_only_replay_and_malformed_capability_refuse(self):
        with patch.object(guard, "_lease", None), patch.dict(os.environ, {"S7TK_CLEANUP_RECORD_DIR": str(guard.DESK_TMP / "old")}, clear=True), patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
            with self.assertRaises(guard.CleanupRefused):
                guard.current_lease()
        for capability in ("[]", "{}", "null"):
            with patch.object(guard, "_lease", None), patch.dict(os.environ, {"KS01_RUN_CAP": capability}, clear=True):
                with self.assertRaises(guard.CleanupRefused):
                    guard.current_lease()

    def test_foreign_owner_generation_and_nonce_refuse(self):
        lease = guard.fresh_lease()
        for altered in (dict(lease, nonce="0" * 64), dict(lease, owner_generation=[1, 0])):
            with patch.object(guard, "_lease", altered), patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
                with self.assertRaises(guard.CleanupRefused):
                    guard.current_lease()

    def test_stale_owner_refuses_even_with_valid_capability(self):
        lease = guard.fresh_lease()
        with patch.object(guard, "_lease", lease), patch.object(guard, "generation", return_value=[1, 0]), patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
            with self.assertRaises(guard.CleanupRefused):
                guard.current_lease()

    def test_ambiguous_global_routes_and_caller_command_queues_refuse(self):
        for argv in (
            ["tmux", "-S", str(guard.DESK_TMP / "private"), "-S", "/private/tmp/tmux-501/default", "new-session", "-d"],
            ["tmux", "-L", "private", "-L", "default", "new-session", "-d"],
            ["tmux", "-S/private/tmp/tmux-501/default", "new-session", "-d"],
            ["tmux", "-L", "private", "new-session", "-d", ";", "kill-server"],
        ):
            with patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
                with self.assertRaises(guard.CleanupRefused):
                    guard.guarded_run(argv)

    def test_absent_socket_is_not_success_while_recorded_server_is_live(self):
        with tempfile.TemporaryDirectory(prefix="ks01-absent-", dir=guard.DESK_TMP) as root:
            path = Path(root) / "absent.sock"
            record = dict(pid=123, generation=[1, 2])
            with patch.object(guard, "load", return_value=record), patch.object(guard, "generation", return_value=[1, 2]), patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
                with self.assertRaises(guard.CleanupRefused):
                    guard.stop(path)
            with patch.object(guard, "load", return_value=record), patch.object(guard, "generation", side_effect=ProcessLookupError("absent")), patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
                self.assertEqual(guard.stop(path).returncode, 0)

    def test_proxy_only_accepts_its_exact_leased_socket(self):
        path = Path(__file__).parent
        result = subprocess.CompletedProcess([], 0)
        with patch.object(guard, "route", return_value=path), patch.object(guard, "guarded_run", return_value=result) as run:
            self.assertIs(guard.proxy_run("private", ["-S", str(path), "list-panes"]), result)
            self.assertEqual(run.call_args.args[0], ["tmux", "-S", str(path), "-f", "/dev/null", "list-panes"])
            run.reset_mock()
            with self.assertRaises(guard.CleanupRefused):
                guard.proxy_run("private", ["-S", "/private/tmp/tmux-501/default", "list-panes"])
            run.assert_not_called()

    def test_strict_tmux_entry_refuses_renamed_executables_before_backend(self):
        for executable in (str(guard.DESK_TMP / "renamed-tmux"), "/bin/sh", "custom-server"):
            with patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
                with self.assertRaises(guard.CleanupRefused):
                    guard.run_tmux([executable, "-L", "private", "new-session", "-d"])

    def test_lingering_dead_owned_socket_is_retired_without_backend(self):
        with tempfile.TemporaryDirectory(prefix="ks01-lingering-", dir=guard.DESK_TMP) as root:
            path = Path(root) / "fixture.sock"
            created = guard.run_tmux(["tmux", "-f", "/dev/null", "-S", str(path), "new-session", "-d", "-s", "ks01-lingering", "/bin/sleep 30"], capture_output=True, text=True, timeout=3)
            self.assertEqual(created.returncode, 0, created.stderr)
            record = guard.load(path)
            try:
                with patch.object(guard, "retire_dead_socket", return_value=None):
                    self.assertEqual(guard.stop(path).returncode, 0)
                self.assertTrue(path.exists(), "fixture must retain its original socket inode")
                self.assertTrue(guard.prior_server_gone(record))
                with patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
                    guard.retire_dead_socket(path, record)
                self.assertFalse(path.exists())
            finally:
                if path.exists():
                    guard.stop(path)

    def test_owned_server_record_generation_and_socket_replacement_refuse(self):
        with tempfile.TemporaryDirectory(prefix="s7tk-native-", dir=Path.home() / "desk/tmp") as root:
            path = Path(root) / "fixture"
            binary = str(Path("/opt/homebrew/bin/tmux").resolve())
            created = guard.guarded_run([binary, "-f", "/dev/null", "-S", str(path), "new-session", "-d", "-s", "test-s7tk", "/bin/sleep 30"], capture_output=True, text=True, timeout=3)
            self.assertEqual(created.returncode, 0, created.stderr)
            try:
                record = guard.load(path)
                altered = dict(record, generation=[record["generation"][0] + 1, record["generation"][1]])
                with patch.object(guard, "load", return_value=altered), patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
                    with self.assertRaises(guard.CleanupRefused):
                        guard.stop(path)
                with patch.dict(os.environ, {"TMUX": f"{path},{record['pid']},0"}), patch.object(guard, "_run", side_effect=AssertionError("backend must not run")):
                    with self.assertRaises(guard.CleanupRefused):
                        guard.stop(path)
                renamed = Path(root) / "prior"
                path.rename(renamed)
                import socket
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as replacement:
                    replacement.bind(str(path))
                    with self.assertRaises(guard.CleanupRefused):
                        guard.stop(path)
                path.unlink()
                renamed.rename(path)
            finally:
                stopped = guard.stop(path, capture_output=True, text=True, timeout=3)
                self.assertEqual(stopped.returncode, 0, stopped.stderr)
                if path.exists():
                    path.unlink()


if __name__ == "__main__":
    unittest.main()
