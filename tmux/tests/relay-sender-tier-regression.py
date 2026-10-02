#!/usr/bin/env python3
# path: ~/.config/tmux/tests/relay-sender-tier-regression.py
# description: Verify sender-aware relay tiers with identity and model evidence.
# date: 2026-10-02T04:00:00Z
import os
import pathlib
import subprocess
import tempfile
import unittest
import hashlib


ROOT = pathlib.Path(__file__).resolve().parents[1]


class SenderTier(unittest.TestCase):
    def test_sender_tiers(self):
        with tempfile.TemporaryDirectory(prefix="relay-sender-tier-") as temp:
            root = pathlib.Path(temp)
            (root / "relay-payload-guard").symlink_to(ROOT / "tools/relay-payload-guard")
            label = root / "relay-sender-label"
            label.write_text("#!/bin/sh\nprintf '%s\\n' \"$MOCK_LABEL\"\n")
            label.chmod(0o755)
            script = r'''
set -uo pipefail
relay_script_dir="$TEST_RELAY_DIR"
TMUX_TIMEOUT_SECONDS=1
TMUX_TIMEOUT_KILL_AFTER=1
fail() { exit 91; }
release_relay_lock() { :; }
request() {
  case "$1" in
    list-panes) printf '%%421 rt2 fable claude 25993 0\n' ;;
    display-message) printf '%%421|%s\n' "$MOCK_IDENTITY" ;;
    capture-pane) printf '%s\n' "$MOCK_CAPTURE" ;;
    *) return 1 ;;
  esac
}
source "$TEST_DELIVERY_MODULE"
resolve_relay_sender_tier
printf '%s\n' "$relay_sender_tier"
'''
            base = {
                **os.environ,
                "TEST_RELAY_DIR": str(root),
                "TEST_DELIVERY_MODULE": str(ROOT / "tools/relay-delivery.sh"),
                "MOCK_LABEL": "%421 rt2 fable 25993 claude",
                "MOCK_IDENTITY": "%421 rt2 fable 25993 0 2.1.287",
            }
            divider = "─" * 80
            cases = (
                ("verified-claude", "  Sonnet 4.6 | context 1k | v2.1.287", {}, "relaxed"),
                ("deepseek-model", "  deepseek-flash | context 1k | v2.1.153", {}, "strict"),
                ("deepseek-wrapper", "  Sonnet 4.6 | context 1k | v2.1.287", {"MOCK_IDENTITY": "%421 rt2 fable 25993 0 claude.exe"}, "strict"),
                ("identity-drift", "  Sonnet 4.6 | context 1k | v2.1.287", {"MOCK_IDENTITY": "%421 rt2 other 25993 0 2.1.287"}, "strict"),
                ("unresolved", "  Sonnet 4.6 | context 1k | v2.1.287", {"MOCK_LABEL": ""}, "strict"),
            )
            for name, status, override, expected in cases:
                with self.subTest(name=name):
                    env = {**base, **override, "MOCK_CAPTURE": f"❯\u00a0\n{divider}\n{status}\n  ⏵⏵ bypass permissions on"}
                    result = subprocess.run(["bash", "-c", script], env=env, capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), expected)
                    if name == "deepseek-model":
                        ambiguous = f"❯\u00a0possible app hint\n{divider}\n  deepseek-flash | v2.1.153\n"
                        guarded = subprocess.run([str(ROOT / "tools/relay-input-guard"), "❯", "2", "0", "80", result.stdout.strip()],
                                                 input=ambiguous, capture_output=True, text=True, timeout=5)
                        self.assertEqual(guarded.returncode, 1, guarded.stderr)
                        self.assertIn("cannot distinguish hint from Home-moved draft", guarded.stderr)

    def test_busy_preflight(self):
        script = r'''
set -uo pipefail
relay_script_dir="$TEST_RELAY_DIR"
TMUX_TIMEOUT_SECONDS=1
TMUX_TIMEOUT_KILL_AFTER=1
pane=%420
relay_glyph="$MOCK_GLYPH"
fail() { exit 91; }
release_relay_lock() { :; }
refuse_draft() { printf '%s\n' "$2"; exit 5; }
source "$TEST_DELIVERY_MODULE"
relay_sender_tier="$MOCK_TIER"
relay_busy_preflight "$MOCK_CAPTURE" "$MOCK_CURSOR_Y"
'''
        with tempfile.TemporaryDirectory(prefix="relay-busy-tier-") as temp:
            root = pathlib.Path(temp)
            (root / "relay-payload-guard").symlink_to(ROOT / "tools/relay-payload-guard")
            divider = "─" * 80
            cc_busy = "\n".join(["history", "✳ Hyperspacing…", "", "", divider, "❯\u00a0", divider, "  Sonnet 4.6 | v2.1.287"])
            cc_historical = "\n".join(["✳ Hyperspacing…", "Completed", "", divider, "❯\u00a0", divider, "  Sonnet 4.6 | v2.1.287"])
            real_cc_busy = (ROOT / "tests/fixtures/rt2-fable-busy-hashing.ansi").read_text()
            self.assertEqual(hashlib.sha256(real_cc_busy.encode()).hexdigest(), "fe19b2e9c2862f15c0d0a730afd9ac918acc57051bb300fb46668551f40caf76")
            real_cc_warping = (ROOT / "tests/fixtures/rt2-fable-busy-warping.ansi").read_text()
            self.assertEqual(hashlib.sha256(real_cc_warping.encode()).hexdigest(), "470378656c9e9362c6165173fe8451459bd035244d26ab1544cdf7b178c87ca9")
            real_agy_busy = (ROOT / "tests/fixtures/rt2-agy-busy-generating.ansi").read_text()
            self.assertEqual(hashlib.sha256(real_agy_busy.encode()).hexdigest(), "9c773bab39f7ca3036b2ef80add63fe9be6cae930288ad318f456608fcb21d69")
            codex_busy = "\n".join(["history", "• Working (0s • esc to interrupt)", "", "", "› Ask Codex to do anything", "  Fast off"])
            codex_busy_hms = "\n".join(["history", "• Working (1h 03m 15s • esc to interrupt)", "", "", "› Ask Codex to do anything", "  Fast off"])
            codex_historical = "\n".join(["• Working (0s • esc to interrupt)", "Completed", "", "", "› Ask Codex to do anything", "  Fast off"])
            cases = (
                ("cc-strict-busy", "❯", "strict", cc_busy, 5, 5),
                ("cc-relaxed-busy", "❯", "relaxed", cc_busy, 5, 0),
                ("cc-historical", "❯", "strict", cc_historical, 4, 0),
                ("cc-busy-timed", "❯", "strict", cc_busy.replace('Hyperspacing…', 'Whirlpooling… (2s · thinking with high effort)'), 5, 5),
                ("cc-busy-timed-relaxed", "❯", "relaxed", cc_busy.replace('Hyperspacing…', 'Whirlpooling… (2s · thinking with high effort)'), 5, 0),
                ("cc-timed-historical", "❯", "strict", cc_historical.replace('Hyperspacing…', 'Whirlpooling… (2s · thinking with high effort)'), 4, 0),
                ("cc-real-hashing-strict", "❯", "strict", real_cc_busy, 52, 5),
                ("cc-real-hashing-relaxed", "❯", "relaxed", real_cc_busy, 52, 0),
                ("cc-real-warping-strict", "❯", "strict", real_cc_warping, 52, 5),
                ("cc-real-warping-relaxed", "❯", "relaxed", real_cc_warping, 52, 0),
                ("codex-strict-busy", "›", "strict", codex_busy, 4, 5),
                ("codex-strict-busy-hms", "›", "strict", codex_busy_hms, 4, 5),
                ("codex-relaxed-busy", "›", "relaxed", codex_busy, 4, 5),
                ("codex-historical", "›", "strict", codex_historical, 4, 0),
                ("agy-real-generating-strict", ">", "strict", real_agy_busy, 41, 5),
                ("agy-real-generating-relaxed", ">", "relaxed", real_agy_busy, 41, 5),
            )
            for name, glyph, tier, capture, cursor_y, expected in cases:
                with self.subTest(name=name):
                    env = {
                        **os.environ,
                        "TEST_RELAY_DIR": str(root),
                        "TEST_DELIVERY_MODULE": str(ROOT / "tools/relay-delivery.sh"),
                        "MOCK_GLYPH": glyph,
                        "MOCK_TIER": tier,
                        "MOCK_CAPTURE": capture,
                        "MOCK_CURSOR_Y": str(cursor_y),
                    }
                    result = subprocess.run(["bash", "-c", script], env=env, capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode, expected, result.stderr)
                    if expected == 5:
                        self.assertIn("an agent busy state", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
