#!/usr/bin/env bash
# path: ~/.config/tmux/tests/relay-input-guard-regression.sh
# description: Check draft refusal, explicit routing, and verified public relay delivery.
# patched: supply safe target dimensions and trash test scratch files
# date: 2026-09-30
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
trap 'trash "$tmpdir"' EXIT

# Captures reproduce the SGR classes observed in live Codex and Claude panes.
codex_placeholder=$'\e[1m\e[38;2;248;183;90m›\e[0m\e[48;2;57;57;71m \e[2mAsk Codex to do anything\e[0m\e[48;2;57;57;71m\n\e[49m  Fast off'
codex_suggestion=$'\e[1m›\e[0m\e[48;2;57;57;71m \e[2mContinue the unresolved tmux capture investigation\e[0m\e[48;2;57;57;71m\n\e[49m  Fast off'
codex_wrapped_suggestion=$'\e[1m›\e[0m\e[48;2;57;57;71m \e[2mContinue the unresolved\n  tmux capture investigation\e[0m\n\e[49m  Fast off'
codex_no_color_suggestion=$'\e[1m\e[38;2;255;178;66m›\e[0m \e[2mContinue the unresolved tmux capture investigation\e[0m\n\n  \e[38;2;200;169;238mFast off\e[39m · \e[38;2;246;226;183mGPT-5.6-Terra\e[39m · \e[38;2;242;181;144mContext 0% used'
codex_256_suggestion=$'\e[1m\e[38;5;215m›\e[0m \e[2mContinue the unresolved tmux capture investigation\e[0m\n\n  \e[38;5;183mFast off\e[39m · \e[38;5;223mGPT-5.6-Terra\e[39m · \e[38;5;216mContext 0% used'
codex_dumb_suggestion=$'\e[1m›\e[0m \e[2mContinue the unresolved tmux capture investigation\e[0m\n\n  Fast off · GPT-5.6-Terra · Context 0% used'
codex_draft=$'\e[1;2m› \e[0m\e[48;2;66;66;79mreal user draft'
codex_rgb_draft=$'\e[1m›\e[0m\e[48;2;66;66;79mreal user draft'
codex_dim_typed=$'\e[1m›\e[0m\e[48;2;57;57;71m \e[2mtyped but dim\e[0m\e[48;2;57;57;71m\n\e[49m  Fast off'
codex_multiline_draft=$'\e[1m›\e[0m\e[48;2;66;66;79m \n  real user draft\n\e[49m  Fast off'
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

printf 'relay input guard regression: PASS\n'
