#!/usr/bin/env bash
# path: ~/.config/tmux/tests/relay-input-guard-regression.sh
# description: Check draft refusal, explicit routing, and verified public relay delivery.
# patched: replay the empty Claude post-delete hint and refuse altered hints
# date: 2026-10-02T04:00:00Z
set -euo pipefail

root="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$root/tools/relay-input-guard"
stub="$root/tests/relay-tmux-stub.sh"
cc_relay="$root/tools/cc-msg.sh"
codex_relay="$root/tools/codex-send"
codex_to_relay="$root/tools/codex-send-to"
agy_relay="$root/tools/agy-send-to"

fail() { printf 'relay input guard regression: %s\n' "$1" >&2; exit 1; }

expect_guard() {
  local expected=$1 glyph=$2 name=$3 capture=$4 cursor_x=$5 cursor_y=$6 code
  set +e
  if [ "$#" = 7 ]; then
    printf '%s\n' "$capture" | "$guard" "$glyph" "$cursor_x" "$cursor_y" "$7" >/dev/null
  else
    printf '%s\n' "$capture" | "$guard" "$glyph" "$cursor_x" "$cursor_y" >/dev/null
  fi
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
cc_footer=$'\n\e[39m  \e[1m\e[38;5;246mOpus 5.5\e[0m\e[90m  |  v2.1.287\n  \e[38;5;211m⏵⏵ bypass permissions on\e[39m'
cc_divider=$(printf '─%.0s' {1..192})
agy_idle=$'\e[90m'"$cc_divider"$'\n\e[94m>\e[39m\n\e[90m'"$cc_divider"$'\n? for shortcuts  \e[2mGemini 3.8 Flash · high\e[0m'
agy_draft=$'\e[90m'"$cc_divider"$'\n\e[94m>\e[39m typed draft\n\e[90m'"$cc_divider"$'\n  \e[2mGemini 3.8 Flash · high\e[0m'
cc_empty=$'\e[39m❯\302\240\n\e[38;5;244m'"$cc_divider""$cc_footer"
cc_placeholder=$'\e[38;5;239m\e[48;5;237m❯ \e[2mTry "create a util logging.py that…"\e[0m\n\e[38;5;244m'"$cc_divider""$cc_footer"
cc_wrapped_placeholder=$'\e[38;5;239m\e[48;5;237m❯ \e[2mTry "create a util\n\e[48;5;237m  logging.py that…"\e[0m\n\e[38;5;244m────────────────────'
cc_empty_footer=$'\e[39m❯\302\240\n\e[38;5;244m────────────────────'"$cc_footer"
cc_placeholder_footer=$'\e[39m❯ \e[2mTry\e[0m \e[2m"create\e[0m \e[2mlogging.py\e[0m \e[2mthat..."\e[0m\n\e[38;5;244m────────────────────'"$cc_footer"
cc_draft_footer=$'\e[39m❯ hello\n\e[38;5;244m────────────────────'"$cc_footer"
cc_dim_non_placeholder=$'❯ \e[2mTry\e[0m\n────────────────────'
cc_draft=$'\e[38;5;239m\e[48;5;237m❯ \e[38;5;231mreal user draft\e[39m'
cc_grey_draft=$'\e[38;5;239m\e[48;5;237m❯ \e[38;5;246mreal user draft\e[39m'
cc_multiline_draft=$'\e[39m❯\302\240\n\e[48;5;237m  real user draft\n\e[38;5;244m────────────────────'
cc_home_whitespace_draft=$'❯    \n────────────────────'
cc_home_dim_draft=$'❯ \e[2mtyped but dim\e[0m\n────────────────────'
cc_dim_continuation_draft=$'❯\302\240\n\e[2m  hidden continuation\e[0m\n────────────────────'
cc_whitespace_continuation_draft=$'❯\302\240\n    \n────────────────────'
cc_concealed_marker=$'❯\e[8m\302\240\e[0m\n────────────────────'
cc_concealed_divider=$'❯\302\240\n\e[8m────────────────────\e[0m'
cc_csi_divider=$'❯\302\240\n\e[2J────────────────────'
cc_zero_padded_concealed_marker=$'❯\e[08m\302\240\e[0m\n────────────────────'
cc_zero_padded_concealed_divider=$'❯\302\240\n\e[0008m────────────────────\e[0m'
codex_concealed_placeholder=$'› \e[2;8mAsk Codex to do anything\e[0m\n\e[49m  Fast off · test · Context 0% used'
codex_dim_continuation_draft=$'› \e[2mAsk Codex to do anything\e[0m\n\e[2m  hidden continuation\e[0m\n\e[49m  Fast off · test · Context 0% used'
codex_whitespace_continuation_draft=$'› \e[2mAsk Codex to do anything\e[0m\n    \n\e[49m  Fast off · test · Context 0% used'
codex_concealed_footer=$'› \e[2mAsk Codex to do anything\e[0m\n\e[49m\e[8m  Fast off · test · Context 0% used\e[0m'
codex_csi_footer=$'› \e[2mAsk Codex to do anything\e[0m\n\e[49m\e[2J  Fast off · test · Context 0% used'
codex_zero_padded_concealed_footer=$'› \e[2mAsk Codex to do anything\e[0m\n\e[49m\e[0;08m  Fast off · test · Context 0% used\e[0m'
mixed_style=$'\e[1m›\e[0m \e[2mplaceholder-looking \e[22mreal draft'

expect_guard 0 '›' 'generic Codex placeholder' "$codex_placeholder" 2 0
expect_guard 1 '›' 'unverified dynamic Codex suggestion' "$codex_suggestion" 2 0
expect_guard 1 '›' 'wrapped unverified Codex suggestion' "$codex_wrapped_suggestion" 2 0
expect_guard 1 '›' 'NO_COLOR unverified Codex suggestion' "$codex_no_color_suggestion" 2 0
expect_guard 1 '›' '256-colour unverified Codex suggestion' "$codex_256_suggestion" 2 0
expect_guard 1 '›' 'TERM=dumb Codex suggestion without a trustworthy footer style' "$codex_dumb_suggestion" 2 0
expect_guard 0 '❯' 'empty Claude composer with NBSP' "$cc_empty" 2 0
expect_guard 0 '❯' 'Claude full-width closing divider' "$cc_empty" 2 0 192
expect_guard 1 '❯' 'Claude divider mismatched to pane width' "$cc_empty" 2 0 191
expect_guard 0 '❯' 'Claude idle reverse-video cursor cell' $'❯\302\240\e[7m \e[0m\n────────────────────'"$cc_footer" 2 0
expect_guard 1 '❯' 'Claude reversed typed space without NBSP' $'❯ \e[7m \e[0m\n────────────────────' 2 0
expect_guard 0 '❯' 'dim Claude Try suggestion' "$cc_placeholder" 2 0
expect_guard 0 '❯' 'empty Claude composer above status and mode footer' "$cc_empty_footer" 2 0
expect_guard 0 '❯' 'Claude Try suggestion above status and mode footer' "$cc_placeholder_footer" 2 0
expect_guard 1 '❯' 'typed Claude draft above footer' "$cc_draft_footer" 8 0
expect_guard 1 '❯' 'Home-moved typed Claude draft above footer' "$cc_draft_footer" 2 0
expect_guard 1 '❯' 'dim non-placeholder Claude text' "$cc_dim_non_placeholder" 2 0
expect_guard 1 '❯' 'dim Claude placeholder with trailing draft' $'❯ \e[2mTry "create"\e[0m typed\n────────────────────' 2 0
expect_guard 1 '❯' 'dim Claude placeholder with extra quoted text' $'❯ \e[2mTry "create" extra"\e[0m\n────────────────────' 2 0
expect_guard 1 '❯' 'unverified wrapped Claude suggestion' "$cc_wrapped_placeholder" 2 0
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
expect_guard 1 '❯' 'Home-moved whitespace Claude draft' "$cc_home_whitespace_draft" 2 0
expect_guard 1 '❯' 'Home-moved dim Claude draft' "$cc_home_dim_draft" 2 0
expect_guard 1 '❯' 'dim Claude continuation draft' "$cc_dim_continuation_draft" 2 0
expect_guard 1 '❯' 'whitespace-only Claude continuation is ambiguous' "$cc_whitespace_continuation_draft" 2 0
expect_guard 1 '❯' 'concealed Claude empty marker is ambiguous' "$cc_concealed_marker" 2 0
expect_guard 1 '❯' 'concealed Claude divider is ambiguous' "$cc_concealed_divider" 2 0
expect_guard 1 '❯' 'non-SGR CSI Claude divider is ambiguous' "$cc_csi_divider" 2 0
expect_guard 1 '❯' 'zero-padded concealed Claude marker is ambiguous' "$cc_zero_padded_concealed_marker" 2 0
expect_guard 1 '❯' 'zero-padded concealed Claude divider is ambiguous' "$cc_zero_padded_concealed_divider" 2 0
expect_guard 1 '›' 'concealed Codex placeholder is ambiguous' "$codex_concealed_placeholder" 2 0
expect_guard 1 '›' 'dim Codex continuation is ambiguous' "$codex_dim_continuation_draft" 2 0
expect_guard 1 '›' 'whitespace-only Codex continuation is ambiguous' "$codex_whitespace_continuation_draft" 2 0
expect_guard 1 '›' 'concealed Codex footer is ambiguous' "$codex_concealed_footer" 2 0
expect_guard 1 '›' 'non-SGR CSI Codex footer is ambiguous' "$codex_csi_footer" 2 0
expect_guard 1 '›' 'zero-padded concealed Codex footer is ambiguous' "$codex_zero_padded_concealed_footer" 2 0
expect_guard 1 '›' 'mixed placeholder and draft text' "$mixed_style" 2 0
expect_guard 2 '›' 'missing Codex composer' $'no composer here' 2 0

# Exercise the public relay scripts, including their exit-5 draft semantics.
expect_relay 1 'codex-missing-window' "$codex_placeholder" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_relay" 'relay payload'
expect_no_delivery 'codex-missing-window'

expect_relay 5 'codex-draft' "$codex_draft" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest CODEX_SEND_WINDOW=codex "$codex_relay" 'relay payload'
expect_no_delivery 'codex-draft'

expect_relay 5 'codex-guard-override-ignored' "$codex_draft" '%relay relaytest codex node' \
  env RELAY_INPUT_GUARD=/usr/bin/true CODEX_SEND_SESSION=relaytest CODEX_SEND_WINDOW=codex "$codex_relay" 'relay payload'
expect_no_delivery 'codex-guard-override-ignored'

expect_relay 5 'codex-to-draft' "$codex_draft" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_to_relay" codex 'relay payload'
expect_no_delivery 'codex-to-draft'

expect_relay 5 'cc-draft' "$cc_draft" '%relay relaytest claude 2.1.284' \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'
expect_no_delivery 'cc-draft'

expect_relay 5 'codex-cursor-race' "$codex_placeholder" '%relay relaytest codex node' \
  env RELAY_TEST_STATE_BEFORE=0:2:0 RELAY_TEST_STATE_AFTER=0:3:0 CODEX_SEND_SESSION=relaytest CODEX_SEND_WINDOW=codex "$codex_relay" 'relay payload'
expect_no_delivery 'codex-cursor-race'

expect_relay 2 'codex-copy-mode' "$codex_placeholder" '%relay relaytest codex node' \
  env RELAY_TEST_PANE_MODE=1 CODEX_SEND_SESSION=relaytest CODEX_SEND_WINDOW=codex "$codex_relay" 'relay payload'
expect_relay 2 'cc-copy-mode' "$cc_empty" '%relay relaytest claude 2.1.284' \
  env RELAY_TEST_PANE_MODE=1 CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'
expect_relay 3 'codex-unresponsive' "$codex_placeholder" '%relay relaytest codex node' \
  env RELAY_TEST_FAIL_COMMAND=list-panes RELAY_TEST_FAIL_STATUS=124 CODEX_SEND_SESSION=relaytest CODEX_SEND_WINDOW=codex "$codex_relay" 'relay payload'
expect_relay 4 'cc-partial' "$cc_empty" '%relay relaytest claude 2.1.284' \
  env RELAY_TEST_RECEIPT_MODE=unknown CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'

expect_relay 0 'codex-placeholder' "$codex_placeholder" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest CODEX_SEND_WINDOW=codex "$codex_relay" 'relay payload'
expect_delivery 'codex-placeholder'

expect_relay 5 'codex-unverified-suggestion' "$codex_suggestion" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest CODEX_SEND_WINDOW=codex "$codex_relay" 'relay payload'
expect_no_delivery 'codex-unverified-suggestion'

expect_relay 0 'codex-to-placeholder' "$codex_placeholder" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_to_relay" codex 'relay payload'
expect_delivery 'codex-to-placeholder'

expect_relay 5 'codex-to-unverified-suggestion' "$codex_suggestion" '%relay relaytest codex node' \
  env CODEX_SEND_SESSION=relaytest "$codex_to_relay" codex 'relay payload'
expect_no_delivery 'codex-to-unverified-suggestion'

expect_relay 0 'cc-empty' "$cc_empty" '%relay relaytest claude 2.1.284' \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'
expect_delivery 'cc-empty'

two_cc_panes=$'%41 relaytest claude 2.1.284\n%42 relaytest claude 2.1.284'
expect_relay 1 'cc-ambiguous' "$cc_empty" "$two_cc_panes" \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude "$cc_relay" 'relay payload'
expect_no_delivery 'cc-ambiguous'
expect_relay 0 'cc-explicit-pane' "$cc_empty" "$two_cc_panes" \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude CC_MSG_PANE=%42 "$cc_relay" 'relay payload'
expect_delivery 'cc-explicit-pane'
expect_relay 1 'cc-pane-outside-window' "$cc_empty" "$two_cc_panes" \
  env CC_MSG_SESSION=relaytest CC_MSG_WINDOW=claude CC_MSG_PANE=%99 "$cc_relay" 'relay payload'
expect_no_delivery 'cc-pane-outside-window'

expect_relay 0 'agy-empty' "$agy_idle" '%relay relaytest gemini agy' \
  env RELAY_TEST_STATE=0:2:1 AGY_SEND_SESSION=relaytest "$agy_relay" gemini 'relay payload'
expect_delivery 'agy-empty'
expect_relay 5 'agy-draft' "$agy_draft" '%relay relaytest gemini agy' \
  env RELAY_TEST_STATE=0:2:1 AGY_SEND_SESSION=relaytest "$agy_relay" gemini 'relay payload'
expect_no_delivery 'agy-draft'
expect_relay 1 'agy-wrong-window' "$agy_idle" '%relay relaytest gemini agy' \
  env RELAY_TEST_STATE=0:2:1 AGY_SEND_SESSION=relaytest "$agy_relay" wrong 'relay payload'
expect_no_delivery 'agy-wrong-window'
two_agy_panes=$'%41 relaytest gemini agy\n%42 relaytest gemini agy'
expect_relay 1 'agy-ambiguous' "$agy_idle" "$two_agy_panes" \
  env RELAY_TEST_STATE=0:2:1 AGY_SEND_SESSION=relaytest "$agy_relay" gemini 'relay payload'
expect_no_delivery 'agy-ambiguous'
expect_relay 0 'agy-explicit-pane' "$agy_idle" "$two_agy_panes" \
  env RELAY_TEST_STATE=0:2:1 AGY_SEND_SESSION=relaytest AGY_SEND_PANE=%42 "$agy_relay" gemini 'relay payload'
expect_delivery 'agy-explicit-pane'
expect_relay 1 'agy-pane-outside-window' "$agy_idle" "$two_agy_panes" \
  env RELAY_TEST_STATE=0:2:1 AGY_SEND_SESSION=relaytest AGY_SEND_PANE=%99 "$agy_relay" gemini 'relay payload'
expect_no_delivery 'agy-pane-outside-window'
expect_relay 1 'agy-bare-shell' "$agy_idle" '%relay relaytest gemini fish' \
  env RELAY_TEST_STATE=0:2:1 AGY_SEND_SESSION=relaytest "$agy_relay" gemini 'relay payload'
expect_no_delivery 'agy-bare-shell'

python3 - "$guard" "$root/tools/relay-payload-guard" "$root/tests/fixtures/relay-codex-main-default.json" "$root/tests/fixtures/relay-codex-live-160.json" "$root/tests/fixtures/relay-codex-cleared-after-edit.json" "$root/tests/fixtures/relay-codex-status-drift.json" "$root/tests/fixtures/relay-codex-home-drafts.json" "$root/tests/fixtures/relay-must-accept.json" "$root/tests/fixtures/relay-must-refuse.json" "$root/tests/fixtures/relay-narrow-payload.json" <<'PY'
import json
import hashlib
import pathlib
import re
import subprocess
import sys
import tempfile

guard, payload_guard, main_fixture, live_fixture, ambiguous_fixture, status_fixture, home_fixture, claude_fixture, refuse_fixture, narrow_fixture = sys.argv[1:]
main_cases = json.loads(pathlib.Path(main_fixture).read_text())["cases"]
live_cases = json.loads(pathlib.Path(live_fixture).read_text())["cases"]
ambiguous_cases = json.loads(pathlib.Path(ambiguous_fixture).read_text())["cases"]
status_cases = json.loads(pathlib.Path(status_fixture).read_text())["cases"]
home_cases = json.loads(pathlib.Path(home_fixture).read_text())["cases"]
claude_cases = json.loads(pathlib.Path(claude_fixture).read_text())["cases"]
refuse_cases = json.loads(pathlib.Path(refuse_fixture).read_text())["cases"]
narrow_case = json.loads(pathlib.Path(narrow_fixture).read_text())
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
    capture = (pathlib.Path(narrow_fixture).parent / narrow_case["capture_file"]).read_bytes()
    meta = (pathlib.Path(narrow_fixture).parent / narrow_case["meta_file"]).read_bytes()
    assert hashlib.sha256(capture).hexdigest() == narrow_case["capture_sha256"]
    assert hashlib.sha256(meta).hexdigest() == narrow_case["meta_sha256"]
    payload_file.write_text(narrow_case["payload"])
    result = subprocess.run([payload_guard, "compare", "❯", str(narrow_case["cursor_x"]), str(narrow_case["cursor_y"]), str(payload_file), str(narrow_case["pane_width"])], input=capture, capture_output=True)
    assert result.returncode == 0, ("deepseek narrow payload", result.returncode)
    checks += 1
    for case in refuse_cases:
        base = pathlib.Path(refuse_fixture).parent
        capture = (base / case["capture_file"]).read_bytes()
        meta = (base / case["meta_file"]).read_bytes()
        assert hashlib.sha256(capture).hexdigest() == case["capture_sha256"]
        assert hashlib.sha256(meta).hexdigest() == case["meta_sha256"]
        result = subprocess.run([guard, case["glyph"], str(case["cursor_x"]), str(case["cursor_y"]), str(case["pane_width"])], input=capture, capture_output=True)
        assert result.returncode == 1, (case["name"], result.returncode)
        checks += 1
    for case in claude_cases:
        base = pathlib.Path(claude_fixture).parent
        capture = (base / case["capture_file"]).read_bytes()
        meta = (base / case["meta_file"]).read_bytes()
        assert hashlib.sha256(capture).hexdigest() == case["capture_sha256"]
        assert hashlib.sha256(meta).hexdigest() == case["meta_sha256"]
        assert pathlib.Path(case["source"]).is_absolute()
        assert (f'cursor={case["cursor_x"]},{case["cursor_y"]}'.encode() in meta or
                meta.split()[5:7] == [str(case["cursor_x"]).encode(), str(case["cursor_y"]).encode()] or
                meta.split()[-2:] == [str(case["cursor_x"]).encode(), str(case["cursor_y"]).encode()])
        result = subprocess.run([guard, case["glyph"], str(case["cursor_x"]), str(case["cursor_y"]), str(case["pane_width"])], input=capture, capture_output=True)
        assert result.returncode == case["input_exit"], (case["name"], result.returncode)
        checks += 1
        if case["name"] == "deepseek-idle-ctrl-y-hint":
            altered = capture.replace(b"Ctrl+Y to paste deleted text", b"Ctrl+Y to paste arbitrary text")
            result = subprocess.run([guard, case["glyph"], str(case["cursor_x"]), str(case["cursor_y"]), str(case["pane_width"])], input=altered, capture_output=True)
            assert result.returncode == 1, (case["name"], "unverified status hint", result.returncode)
            checks += 1
        rows = capture.decode().splitlines()
        rows[case["cursor_y"]] = rows[case["cursor_y"]].replace(case["glyph"], case["glyph"] + " drafted ", 1)
        result = subprocess.run([guard, case["glyph"], str(case["cursor_x"]), str(case["cursor_y"]), str(case["pane_width"])], input=("\n".join(rows) + "\n").encode(), capture_output=True)
        assert result.returncode == 1, (case["name"], "Home-moved draft", result.returncode)
        checks += 1
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
        rows = capture.splitlines()
        rows.insert(case["cursor_y"] + 1, "\x1b[2m  dim draft continuation\x1b[0m")
        check_guard(case, 1, capture="\n".join(rows) + "\n")
        check_guard(case, 1, cursor_x=case["cursor_x"] + 1)
    for case in live_cases:
        check_guard(case, case["input_exit"])
    for case in ambiguous_cases:
        check_guard(case, case["input_exit"])
        check_guard(case, 1, cursor_x=case["cursor_x"] - 1)
        check_guard(case, 1, cursor_x=case["cursor_x"] + 1)
    for case in status_cases:
        check_guard(case, case["input_exit"])
        if case.get("payload"):
            check_payload(case, case["payload_exit"])
            check_payload(case, 1, payload="X" + case["payload"][1:])
            check_payload(case, 1, cursor_x=case["cursor_x"] + 1)
    for case in home_cases:
        check_guard(case, case["input_exit"])
    restored = next(case for case in home_cases if case["name"] == "restored-placeholder-after-backspace")
    check_guard(restored, 1, capture=restored["capture"] + "\x1b[2m  dim text after footer\x1b[0m\n")
    reconnected_payload = next(case for case in status_cases if case["name"] == "reconnected-main-default-payload")
    check_payload(reconnected_payload, 1, capture=reconnected_payload["capture"].replace("Main [default]", "Main [other]"))
    no_context_empty = next(case for case in status_cases if case["name"] == "no-context-terra-empty")
    no_context_unstyled = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", no_context_empty["capture"])
    check_guard(no_context_empty, 1, capture=no_context_unstyled)
    check_guard(no_context_empty, 1, capture=no_context_empty["capture"].replace("for agents", "for agents arbitrary"))
    check_guard(no_context_empty, 1, capture=no_context_empty["capture"].replace("for agents", "Main [default] · for agents"))
    no_context_rows = no_context_empty["capture"].splitlines()
    no_context_rows.insert(no_context_empty["cursor_y"] + 3, "  visible draft tail")
    check_guard(no_context_empty, 1, capture="\n".join(no_context_rows) + "\n")
    no_context_payload = next(case for case in status_cases if case["name"] == "no-context-terra-payload")
    check_payload(no_context_payload, 1, capture=re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", no_context_payload["capture"]))
    fresh = next(case for case in live_cases if case["name"] == "sol-fresh")
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
    for middle in ("  undimmed draft continuation", "\x1b[2m  dim draft continuation\x1b[0m", ""):
        rows = lines.copy()
        rows.insert(fresh["cursor_y"] + 1, middle)
        check_guard(fresh, 1, capture="\n".join(rows) + "\n")
    check_guard(fresh, 1, capture=fresh["capture"].replace("Ask Codex", "\x1b[8mAsk Codex", 1))
    rows = lines.copy()
    del rows[fresh["cursor_y"] + 1]
    check_guard(fresh, 1, capture="\n".join(rows) + "\n")
    draft = next(case for case in live_cases if case["name"] == "sol-single-line-draft")
    check_guard(draft, 1, cursor_x=2)
    rows = draft["capture"].splitlines()
    rows.insert(draft["cursor_y"] + 1, "  real wrapped draft")
    check_guard(draft, 1, capture="\n".join(rows) + "\n", cursor_x=6, cursor_y=draft["cursor_y"] + 1)
    check_guard(fresh, 1, cursor_x=3)
    busy = no_context_payload
    rows = busy["capture"].splitlines()
    rows[busy["cursor_y"] + 2] = rows[busy["cursor_y"] + 2].replace("for agents", "unknown action")
    check_payload(busy, 1, capture="\n".join(rows) + "\n")
    print(f"captured provenance-verified Codex guards: {checks} checks, PASS")
finally:
    subprocess.run(["trash", str(scratch)], check=True)
PY

printf 'relay input guard regression: PASS\n'
