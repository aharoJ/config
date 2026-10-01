#!/usr/bin/env bash
# path: ~/.config/tmux/tests/relay-input-guard-regression.sh
# description: Check draft refusal, explicit routing, and verified public relay delivery.
# patched: reject footer-shaped lines inside Codex draft tails
# date: 2026-10-01T14:12:00-0700
set -euo pipefail

root="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$root/tools/relay-input-guard"
stub="$root/tests/relay-tmux-stub.sh"
cc_relay="$root/tools/cc-msg.sh"
codex_relay="$root/tools/codex-send"
codex_to_relay="$root/tools/codex-send-to"

fail() { printf 'relay input guard regression: %s\n' "$1" >&2; exit 1; }

expect_guard() {
  local expected=$1 glyph=$2 name=$3 capture=$4 cursor_x=$5 cursor_y=$6 code
  set +e
  printf '%s\n' "$capture" | "$guard" "$glyph" "$cursor_x" "$cursor_y" >/dev/null
  code=$?
  set -e
  [ "$code" = "$expected" ] || fail "$name returned $code, expected $expected"
}

expect_relay() {
  local expected=$1 name=$2 capture=$3 panes=$4
  shift 4
  : > "$tmpdir/$name.log"
  set +e
  TMUX="$tmpdir/socket,0,0" \
    TMUX_BIN="$stub" \
    TMUX_RELAY_LOCK_ROOT="$tmpdir/locks" \
    RELAY_TEST_CAPTURE="$capture" \
    RELAY_TEST_LOG="$tmpdir/$name.log" \
    RELAY_TEST_STATE_COUNT_FILE="$tmpdir/$name.state-count" \
    RELAY_TEST_PANES="$panes" \
    "$@" >/dev/null 2>&1
  code=$?
  set -e
  [ "$code" = "$expected" ] || fail "$name returned $code, expected $expected"
}

expect_no_delivery() {
  local name=$1
  if rg -q '^if-shell$' "$tmpdir/$name.log"; then
    fail "$name attempted delivery after refusing a draft"
  fi
}

expect_delivery() {
  local name=$1
  rg -q '^if-shell$' "$tmpdir/$name.log" || fail "$name never reached guarded delivery"
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/relay-input-guard.XXXXXX")"
trap 'rm -rf -- "$tmpdir"' EXIT
mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/trash" <<'EOF'
#!/usr/bin/env bash
rm -rf -- "$@"
EOF
chmod +x "$tmpdir/bin/trash"
export PATH="$tmpdir/bin:$PATH"

# Captures reproduce the SGR classes observed in live Codex and Claude panes.
codex_placeholder=$'\e[1m\e[38;2;248;183;90m›\e[0m\e[48;2;57;57;71m \e[2mAsk Codex to do anything\e[0m\e[48;2;57;57;71m\n\e[49m  Fast off · test · Context 0% used'
codex_suggestion=$'\e[1m›\e[0m\e[48;2;57;57;71m \e[2mContinue the unresolved tmux capture investigation\e[0m\e[48;2;57;57;71m\n\e[49m  Fast off · test · Context 0% used'
codex_wrapped_suggestion=$'\e[1m›\e[0m\e[48;2;57;57;71m \e[2mContinue the unresolved\n  tmux capture investigation\e[0m\n\e[49m  Fast off · test · Context 0% used'
codex_no_color_suggestion=$'\e[1m\e[38;2;255;178;66m›\e[0m \e[2mContinue the unresolved tmux capture investigation\e[0m\n\n  \e[38;2;200;169;238mFast off\e[39m · \e[38;2;246;226;183mGPT-5.6-Terra\e[39m · \e[38;2;242;181;144mContext 0% used'
codex_256_suggestion=$'\e[1m\e[38;5;215m›\e[0m \e[2mContinue the unresolved tmux capture investigation\e[0m\n\n  \e[38;5;183mFast off\e[39m · \e[38;5;223mGPT-5.6-Terra\e[39m · \e[38;5;216mContext 0% used'
codex_dumb_suggestion=$'\e[1m›\e[0m \e[2mContinue the unresolved tmux capture investigation\e[0m\n\n  Fast off · GPT-5.6-Terra · Context 0% used'
codex_draft=$'\e[1;2m› \e[0m\e[48;2;66;66;79mreal user draft'
codex_rgb_draft=$'\e[1m›\e[0m\e[48;2;66;66;79mreal user draft'
codex_dim_typed=$'\e[1m›\e[0m\e[48;2;57;57;71m \e[2mtyped but dim\e[0m\e[48;2;57;57;71m\n\e[49m  Fast off · test · Context 0% used'
codex_multiline_draft=$'\e[1m›\e[0m\e[48;2;66;66;79m \n  real user draft\n\e[49m  Fast off · test · Context 0% used'
codex_footer_lookalike_draft=$'› \n\n  Fast off · model · ~/repo · Context 0% used\n  REAL USER DRAFT\n\e[49m  Fast off · model · ~/repo · Context 0% used'
codex_colored_footer_lookalike_draft=$'› \n\n  \e[38;5;183mFast off · model · Context 0% used\n  REAL USER DRAFT\n\e[49m  Fast off · model · Context 0% used'
codex_choice=$'\e[1m\e[38;2;0;0;46m\e[48;2;99;168;248m› 1. Trust and continue'
cc_empty=$'\e[39m❯\302\240\n\e[38;5;244m────────────────────'
cc_placeholder=$'\e[38;5;239m\e[48;5;237m❯ \e[2mTry "create a util logging.py that…"\e[0m\n\e[38;5;244m────────────────────'
cc_wrapped_placeholder=$'\e[38;5;239m\e[48;5;237m❯ \e[2mTry "create a util\n\e[48;5;237m  logging.py that…"\e[0m\n\e[38;5;244m────────────────────'
cc_draft=$'\e[38;5;239m\e[48;5;237m❯ \e[38;5;231mreal user draft\e[39m'
cc_grey_draft=$'\e[38;5;239m\e[48;5;237m❯ \e[38;5;246mreal user draft\e[39m'
cc_multiline_draft=$'\e[39m❯\302\240\n\e[48;5;237m  real user draft\n\e[38;5;244m────────────────────'
mixed_style=$'\e[1m›\e[0m \e[2mplaceholder-looking \e[22mreal draft'

expect_guard 0 '›' 'generic Codex placeholder' "$codex_placeholder" 2 0
expect_guard 0 '›' 'dynamic Codex suggestion' "$codex_suggestion" 2 0
expect_guard 0 '›' 'wrapped dynamic Codex suggestion' "$codex_wrapped_suggestion" 2 0
expect_guard 0 '›' 'NO_COLOR Codex suggestion with structured footer' "$codex_no_color_suggestion" 2 0
expect_guard 0 '›' '256-colour Codex suggestion with structured footer' "$codex_256_suggestion" 2 0
expect_guard 1 '›' 'TERM=dumb Codex suggestion without a trustworthy footer style' "$codex_dumb_suggestion" 2 0
expect_guard 0 '❯' 'empty Claude composer with NBSP' "$cc_empty" 2 0
expect_guard 0 '❯' 'dynamic Claude suggestion' "$cc_placeholder" 2 0
expect_guard 0 '❯' 'wrapped dynamic Claude suggestion' "$cc_wrapped_placeholder" 2 0
expect_guard 1 '›' 'typed Codex draft' "$codex_draft" 3 0
expect_guard 1 '›' 'RGB-background Codex draft' "$codex_rgb_draft" 3 0
expect_guard 1 '›' 'typed but dim Codex draft advances cursor' "$codex_dim_typed" 3 0
expect_guard 1 '›' 'multiline Codex draft' "$codex_multiline_draft" 4 1
expect_guard 1 '›' 'plain Codex footer lookalike before draft content' "$codex_footer_lookalike_draft" 2 0
expect_guard 1 '›' 'colored Codex footer lookalike before draft content' "$codex_colored_footer_lookalike_draft" 2 0
expect_guard 1 '›' 'Codex choice row' "$codex_choice" 2 0
expect_guard 1 '❯' 'typed Claude draft' "$cc_draft" 3 0
expect_guard 1 '❯' 'grey Claude draft' "$cc_grey_draft" 3 0
expect_guard 1 '❯' 'multiline Claude draft' "$cc_multiline_draft" 4 1
expect_guard 1 '›' 'mixed placeholder and draft text' "$mixed_style" 2 0
expect_guard 2 '›' 'missing Codex composer' $'no composer here' 2 0

# Exercise the public relay scripts, including their exit-5 draft semantics.
expect_relay 5 'codex-draft' "$codex_draft" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_relay" 'relay payload'
expect_no_delivery 'codex-draft'

expect_relay 5 'codex-guard-override-ignored' "$codex_draft" '%relay relaytest codex node' \
  env RELAY_INPUT_GUARD=/usr/bin/true CODEX_SEND_SESSION=relaytest "$codex_relay" 'relay payload'
expect_no_delivery 'codex-guard-override-ignored'

expect_relay 5 'codex-to-draft' "$codex_draft" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_to_relay" codex 'relay payload'
expect_no_delivery 'codex-to-draft'

expect_relay 5 'cc-draft' "$cc_draft" '%relay relaytest claude 2.1.284' \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'
expect_no_delivery 'cc-draft'

expect_relay 5 'codex-cursor-race' "$codex_placeholder" '%relay relaytest codex node' \
  env RELAY_TEST_STATE_BEFORE=0:2:0 RELAY_TEST_STATE_AFTER=0:3:0 CODEX_SEND_SESSION=relaytest "$codex_relay" 'relay payload'
expect_no_delivery 'codex-cursor-race'

expect_relay 2 'codex-copy-mode' "$codex_placeholder" '%relay relaytest codex node' \
  env RELAY_TEST_PANE_MODE=1 CODEX_SEND_SESSION=relaytest "$codex_relay" 'relay payload'
expect_relay 2 'cc-copy-mode' "$cc_placeholder" '%relay relaytest claude 2.1.284' \
  env RELAY_TEST_PANE_MODE=1 CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'
expect_relay 3 'codex-unresponsive' "$codex_placeholder" '%relay relaytest codex node' \
  env RELAY_TEST_FAIL_COMMAND=list-panes RELAY_TEST_FAIL_STATUS=124 CODEX_SEND_SESSION=relaytest "$codex_relay" 'relay payload'
expect_relay 4 'cc-partial' "$cc_placeholder" '%relay relaytest claude 2.1.284' \
  env RELAY_TEST_RECEIPT_MODE=unknown CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'

expect_relay 0 'codex-placeholder' "$codex_placeholder" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_relay" 'relay payload'
expect_delivery 'codex-placeholder'

expect_relay 0 'codex-suggestion' "$codex_suggestion" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_relay" 'relay payload'
expect_delivery 'codex-suggestion'

expect_relay 0 'codex-to-placeholder' "$codex_placeholder" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_to_relay" codex 'relay payload'
expect_delivery 'codex-to-placeholder'

expect_relay 0 'codex-to-suggestion' "$codex_suggestion" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_to_relay" codex 'relay payload'
expect_delivery 'codex-to-suggestion'

expect_relay 0 'cc-placeholder' "$cc_placeholder" '%relay relaytest claude 2.1.284' \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'
expect_delivery 'cc-placeholder'

two_cc_panes=$'%41 relaytest claude 2.1.284\n%42 relaytest claude 2.1.284'
expect_relay 1 'cc-ambiguous' "$cc_placeholder" "$two_cc_panes" \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'
expect_no_delivery 'cc-ambiguous'
expect_relay 0 'cc-explicit-pane' "$cc_placeholder" "$two_cc_panes" \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude CC_MSG_PANE=%42 "$cc_relay" 'relay payload'
expect_delivery 'cc-explicit-pane'
expect_relay 1 'cc-pane-outside-window' "$cc_placeholder" "$two_cc_panes" \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude CC_MSG_PANE=%99 "$cc_relay" 'relay payload'
expect_no_delivery 'cc-pane-outside-window'

python3 - "$guard" "$root/tools/relay-payload-guard" "$root/tests/fixtures/relay-codex-159.json" "$root/tests/fixtures/relay-codex-main-default.json" "$root/tests/fixtures/relay-codex-live-160.json" "$root/tests/fixtures/relay-codex-cleared-after-edit.json" <<'PY'
import json
import pathlib
import re
import subprocess
import sys
import tempfile

guard, payload_guard, fixture, main_fixture, live_fixture, cleared_fixture = sys.argv[1:]
cases = json.loads(pathlib.Path(fixture).read_text())["cases"]
main_cases = json.loads(pathlib.Path(main_fixture).read_text())["cases"]
live_cases = json.loads(pathlib.Path(live_fixture).read_text())["cases"]
cleared_cases = json.loads(pathlib.Path(cleared_fixture).read_text())["cases"]
scratch = pathlib.Path(tempfile.mkdtemp(prefix="relay-captured-159-"))
payload_file = scratch / "payload"
checks = 0

def check_guard(case, expected, capture=None, cursor_x=None, cursor_y=None):
    global checks
    result = subprocess.run([guard, "›", str(case["cursor_x"] if cursor_x is None else cursor_x),
                             str(case["cursor_y"] if cursor_y is None else cursor_y)],
                            input=case["capture"] if capture is None else capture, text=True, capture_output=True)
    assert result.returncode == expected, (case["name"], result.returncode, expected, result.stderr)
    checks += 1

def check_payload(case, expected, capture=None, payload=None, cursor_x=None):
    global checks
    payload_file.write_text(case["payload"] if payload is None else payload)
    result = subprocess.run([payload_guard, "compare", "›", str(case["cursor_x"] if cursor_x is None else cursor_x),
                             str(case["cursor_y"]), str(payload_file), str(case["width"])],
                            input=case["capture"] if capture is None else capture, text=True, capture_output=True)
    assert result.returncode == expected, (case["name"], result.returncode, expected, result.stderr)
    checks += 1

try:
    for case in cases:
        check_guard(case, case["input_exit"])
        if case["payload"]:
            check_payload(case, 0)
            check_payload(case, 1, payload="X" + case["payload"][1:])
            check_payload(case, 1, payload=case["payload"][:-1])
            check_payload(case, 1, cursor_x=case["cursor_x"] + 1)
            rows = case["capture"].splitlines()
            rows.insert(case["cursor_y"] + 1, "  hidden extra input")
            check_payload(case, 1, capture="\n".join(rows) + "\n")
    for case in main_cases:
        check_guard(case, case["input_exit"])
        capture = case["capture"]
        check_guard(case, 0, capture=capture.replace(" · Main [default]", ""))
        check_guard(case, 0, capture=capture.replace("\x1b[1m›", "\x1b[1m\x1b[38;2;248;183;90m›", 1))
        check_guard(case, 1, capture=capture.replace("Main [default]", "Main [other]"))
        check_guard(case, 1, capture=capture.replace("Main [default]", "Main [default] · Main [default]"))
        check_guard(case, 1, capture=capture.replace("for agents", "for agents arbitrary"))
        check_guard(case, 1, capture=capture.replace("\x1b[49m", "\x1b[49m\x1b[48;2;57;57;71m", 1))
        check_guard(case, 1, capture=capture.replace("Main [default]", "Main \x1b]8;;https://example.invalid\x1b\\[default]"))
        rows = capture.splitlines()
        rows.insert(case["cursor_y"] + 1, "  hidden draft continuation")
        check_guard(case, 1, capture="\n".join(rows) + "\n")
        check_guard(case, 1, cursor_x=case["cursor_x"] + 1)
    for case in live_cases:
        check_guard(case, case["input_exit"])
    for case in cleared_cases:
        check_guard(case, case["input_exit"])
        capture = case["capture"]
        check_guard(case, 1, capture=capture.replace("\x1b[48;2;57;57;71m", ""))
        check_guard(case, 1, capture=capture.replace("57;57;71", "66;66;79"))
        check_guard(case, 1, capture=capture.replace("Main [default]", "Main [other]"))
        check_guard(case, 1, cursor_x=case["cursor_x"] - 1)
        check_guard(case, 1, cursor_x=case["cursor_x"] + 1)
    fresh = next(case for case in cases if case["name"] == "fresh-with-startup-tip")
    lines = fresh["capture"].splitlines()
    index = fresh["cursor_y"] + 2
    footer = lines[index]
    mutations = [footer.replace(" · ~/.config", ""), footer.replace("Context 0%", "Context 101%"),
                 footer + " arbitrary", "\x1b[48;5;237m" + footer,
                 footer + "\x1b]8;;https://example.invalid\x1b\\", footer.replace("Fast off", "Fast unknown")]
    for mutated in mutations:
        rows = lines.copy()
        rows[index] = mutated
        check_guard(fresh, 1, capture="\n".join(rows) + "\n")
    for middle in ("  undimmed draft continuation", ""):
        rows = lines.copy()
        rows.insert(fresh["cursor_y"] + 1, middle)
        check_guard(fresh, 1, capture="\n".join(rows) + "\n")
    rows = lines.copy()
    del rows[fresh["cursor_y"] + 1]
    check_guard(fresh, 1, capture="\n".join(rows) + "\n")
    draft = next(case for case in cases if case["name"] == "real-typed-draft")
    check_guard(draft, 1, cursor_x=2)
    rows = draft["capture"].splitlines()
    rows.insert(draft["cursor_y"] + 1, "  real wrapped draft")
    check_guard(draft, 1, capture="\n".join(rows) + "\n", cursor_x=6, cursor_y=draft["cursor_y"] + 1)
    check_guard(fresh, 1, cursor_x=3)
    busy = next(case for case in cases if case["name"] == "busy-exact-payload")
    rows = busy["capture"].splitlines()
    rows[busy["cursor_y"] + 2] = rows[busy["cursor_y"] + 2].replace("queue message", "unknown action")
    check_payload(busy, 1, capture="\n".join(rows) + "\n")
    print(f"captured Codex 0.159.2 guards: {checks} checks, PASS")
finally:
    subprocess.run(["trash", str(scratch)], check=True)
PY

printf 'relay input guard regression: PASS\n'
