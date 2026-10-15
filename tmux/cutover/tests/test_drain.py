import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("drain", Path(__file__).resolve().parents[1] / "drain.py")
drain = importlib.util.module_from_spec(spec)
spec.loader.exec_module(drain)


class DrainTests(unittest.TestCase):
    def test_pre_handoff_entries_are_senders(self):
        with tempfile.TemporaryDirectory(dir=Path.home() / "desk/tmp") as temporary:
            package = Path(temporary)
            (package / "transport.json").write_text("{}")
            rows = "\n".join([
                "21 1 /usr/bin/python3 /package/cc-msg.sh hello",
                "22 1 /usr/bin/python3 /package/relay exact:target hello",
                f"23 1 /usr/bin/python3 -B {package}/launch hello",
                "24 1 /bin/bash /package/codex-model fast",
                "25 1 /bin/bash /package/codex-new-chat hello",
            ])
            self.assertEqual([row["pid"] for row in drain.sender_processes(rows)], [21, 22, 23, 24, 25])

    def test_unquoted_process_tail_cannot_hide_a_sender(self):
        for row in [
            "201 1 /usr/bin/python3 /package/cc-msg.sh Angel's task",
            "202 1 /bin/bash /package/codex-model Angel's task",
            "203 1 /usr/bin/python3 /package/codex-send-to codex Don't resend",
            "204 1 /usr/bin/python3 -W ignore /package/cc-msg hello",
            "205 1 /usr/bin/python3 -X dev /package/cc-msg hello",
        ]:
            with self.assertRaises(ValueError):
                drain.sender_processes(row)

    def test_live_senders_are_distinct_from_readers(self):
        rows = "\n".join([
            "10 1 /usr/bin/python3 /package/relay-core --deliver /inbox/attempt.json",
            "11 1 /package/angelstar-runtime --surface cc-msg hello",
            "12 1 /package/angelstar-runtime --surface relay status " + "a" * 32,
            "13 1 /package/angelstar-runtime --surface relay read " + "b" * 32 + " wire",
            "14 1 /package/angelstar-runtime --surface codex-send --help",
            "15 1 /package/angelstar-runtime --surface relay exact:target hello",
        ])
        self.assertEqual([row["pid"] for row in drain.sender_processes(rows)], [10, 11, 15])
        with self.assertRaises(ValueError):
            drain.sender_processes("10 1 /package/angelstar-runtime --unexpected")

    def test_retired_errors_preserve_uncertainty_without_blocking_other_peers(self):
        with tempfile.TemporaryDirectory(dir=Path.home() / "desk/tmp") as temporary:
            root = Path(temporary)
            folder = root / "inbox"
            folder.mkdir()
            value = {"id": "old", "state": "error", "target": {"pane_id": "%1", "pane_pid": "99"}}
            path = folder / "old.json"
            path.write_text(json.dumps(value))
            result = drain.legacy_records([root], {"%1": "99"})
            self.assertEqual(len(result["blockers"]), 1)
            result = drain.legacy_records([root], {"%1": "100"})
            self.assertFalse(result["blockers"])
            self.assertEqual(len(result["retained_terminal_no_replay"]), 1)
            value["state"] = "waiting"
            path.write_text(json.dumps(value))
            self.assertEqual(len(drain.legacy_records([root], {})["blockers"]), 1)

    def test_unsettled_rust_attempts_refuse_drain(self):
        with tempfile.TemporaryDirectory(dir=Path.home() / "desk/tmp") as temporary:
            root = Path(temporary)
            ledger = {"schema": "angelstar-store", "version": 1, "revision": 0, "attempts": []}
            path = root / "ledger.json"
            path.write_text(json.dumps(ledger))
            self.assertFalse(drain.rust_store(root)["blockers"])
            for state in ["pending-no-input", "input-intent", "pasted", "waiting-for-focus-release", "submit-intent", "input-unknown"]:
                ledger["attempts"] = [{"id": state, "history": [{"state": state}]}]
                path.write_text(json.dumps(ledger))
                self.assertEqual(len(drain.rust_store(root)["blockers"]), 1)

    def test_only_live_generation_locks_block(self):
        with tempfile.TemporaryDirectory(dir=Path.home() / "desk/tmp") as temporary:
            root = Path(temporary)
            lock = root / "target-7000001-1-9000002"
            lock.write_bytes(b"unsettled")
            os.chmod(lock, 0o600)
            socket = root / "server"
            generation = lambda pid: [9, 2]
            active, retired = drain.target_locks(socket, {"%1": "42"}, 7000001, generation)
            self.assertEqual(active, [str(lock)])
            self.assertFalse(retired)
            for panes, server in [({}, 7000001), ({"%1": "42"}, 7000002)]:
                active, retired = drain.target_locks(socket, panes, server, generation)
                self.assertFalse(active)
                self.assertEqual(retired, [str(lock)])
            self.assertEqual(lock.read_bytes(), b"unsettled")


if __name__ == "__main__":
    unittest.main()
