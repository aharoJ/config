import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("stage-callers.py")


class CallerMigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(
            prefix="s6x-callers-", dir=Path.home() / "desk/tmp"
        )
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.repo = self.root / "repo"
        self.audit = self.root / "audit"
        self.audit.mkdir()
        self.sources = {}
        self.write(
            ".codex/AGENTS.md",
            "# Agreements\nNever use Claude headlessly.\n"
            "### Sending CC a message\nOld contract\n## Relay routing\nShared evidence.\n",
        )
        for project in ["first", "second"]:
            self.write(
                f".claude/projects/{project}/memory/feedback_never_hand_back_relay.md",
                "# Current routing\nExit 6 means the queue owns delivery: do not resend. "
                "Exit 3/4 means unknown or potentially partial delivery: inspect before any further action.\n",
            )
        self.write(
            ".claude/projects/first/memory/feedback_no_pane_polling.md",
            "Set CC_MSG_SESSION/CC_MSG_WINDOW; check target.session_name in the relay record.\n",
        )
        self.write(
            ".claude/projects/first/memory/MEMORY.md",
            "Own authorized relay routing — honor refusals and queue ownership; never raw keys\n",
        )
        self.write(
            ".claude/projects/first/memory/historical-unrelated.md",
            "Historical incident: gpg returned exit 2. Do not change this observation.\n",
        )
        (self.audit / "s6x-caller-discovery.txt").write_text(
            "\n".join(str(p) for p in self.sources) + "\n"
        )

    def write(self, relative, content):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        self.sources[path] = path.read_bytes()

    def run_migration(self):
        subprocess.run(
            [sys.executable, str(SCRIPT), "--home", str(self.home),
             "--repo", str(self.repo), "--audit", str(self.audit)],
            check=True, capture_output=True,
        )
        return json.loads((self.audit / "s6x-doc-migration.json").read_text())

    def test_regeneration_is_idempotent_and_sources_unchanged(self):
        first = self.run_migration()
        first_bytes = {e["stagedpath"]: Path(e["stagedpath"]).read_bytes()
                       for e in first["entries"]}
        second = self.run_migration()
        self.assertEqual(first, second)
        self.assertEqual(first_bytes,
                         {e["stagedpath"]: Path(e["stagedpath"]).read_bytes()
                          for e in second["entries"]})
        for path, before in self.sources.items():
            self.assertEqual(path.read_bytes(), before)
        for entry in second["entries"]:
            self.assertEqual(hashlib.sha256(Path(entry["path"]).read_bytes()).hexdigest(),
                             entry["beforehash"])
            self.assertEqual(hashlib.sha256(Path(entry["stagedpath"]).read_bytes()).hexdigest(),
                             entry["afterhash"])

    def test_both_active_copies_and_legacy_rust_outcomes(self):
        manifest = self.run_migration()
        by_path = {e["path"]: e for e in manifest["entries"]}
        for project in ["first", "second"]:
            source = self.home / f".claude/projects/{project}/memory/feedback_never_hand_back_relay.md"
            text = Path(by_path[str(source)]["stagedpath"]).read_text()
            self.assertIn("foreground invocation ended before a producer", text)
            self.assertIn("no background worker survives", text)
            self.assertIn("explicit recover is deferred", text)
            self.assertIn("Legacy Python exit 6 remains queue-owned", text)
            self.assertIn("Rust exit 4 and legacy Python exits 3/4", text)
            self.assertIn("originating immutable Rust package/store", text)
            self.assertNotIn("Exit 6 means the queue owns delivery", text)
        global_entry = by_path[str(self.home / ".codex/AGENTS.md")]
        text = Path(global_entry["stagedpath"]).read_text()
        self.assertIn("CC_MSG_SESSION=<session> CC_MSG_WINDOW=<exact-window-name> ~/.local/bin/cc-msg", text)
        self.assertIn("CODEX_SEND_SESSION=<session>", text)
        self.assertIn("existing visible interactive target", text)
        self.assertIn("Rust has no send exits 2/3/5", text)
        self.assertIn("submitted", text)
        self.assertIn("recipient receipt `unproved`", text)
        self.assertIn("Successful help/read/status exits 0 only for that operation", text)
        self.assertIn("Inherited store/socket values must match", text)
        self.assertNotRegex(text, r"ANGELSTAR_RELAY_(STORE|SOCKET)=[^\s`]+")
        unrelated = self.home / ".claude/projects/first/memory/historical-unrelated.md"
        self.assertNotIn(str(unrelated), by_path)
        index = self.home / ".claude/projects/first/memory/MEMORY.md"
        self.assertIn("Rust foreground pending and legacy Python queue ownership",
                      Path(by_path[str(index)]["stagedpath"]).read_text())

    def test_target_field_migration_remains_dual_readable(self):
        manifest = self.run_migration()
        entry = next(e for e in manifest["entries"]
                     if e["path"].endswith("feedback_no_pane_polling.md"))
        text = Path(entry["stagedpath"]).read_text()
        self.assertIn("announcement/status numeric `peer`", text)
        self.assertIn("relay status <attempt-id>", text)
        self.assertIn("relay read <archive-id> wire", text)
        self.assertIn("even after rollback", text)
        self.assertIn("legacy Python", text)
        self.assertIn("target.session_name", text)
        self.assertNotRegex(text, r"check target\.session_name")


if __name__ == "__main__":
    unittest.main()
