#!/usr/bin/env bash
# path: ~/.config/tmux/tools/cc-msg.sh
# description: Deliver text to an explicitly selected agent with fail-closed payload verification.
# patched: bound submission jobs and verify signed CC hub return routes
# date: 2026-10-06
set -uo pipefail

if [ "${1:-}" = --clear-draft ]; then
  clear_tool="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().with_name("relay-clear-draft"))' "${BASH_SOURCE[0]}")" || exit 7
  shift
  exec python3 "$clear_tool" claude "$@"
fi

if [ "${CC_MSG_QUEUE_INTERNAL:-}" != 1 ]; then
  queue_tool="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().with_name("cc-msg-queue"))' "${BASH_SOURCE[0]}")" || exit 7
  exec python3 "$queue_tool" "$@"
fi

fail() { [ "${relay_operator_ready:-0}" != 1 ] || partial "operator replacement stopped after clear: $1"; printf 'cc-msg: %s; no target input was sent; safe to retry after the condition clears\n' "$1" >&2; exit 1; }
refuse_copy() { [ "${relay_operator_ready:-0}" != 1 ] || partial "operator replacement stopped after clear: $1"; printf 'cc-msg: target %s is in copy mode; no target input was sent; safe to retry after the condition clears\n' "$1" >&2; exit 2; }
unresponsive() { relay_server_unresponsive=1; printf 'cc-msg: tmux server is unresponsive; delivery state is unknown; do not resend automatically\n' >&2; exit 3; }
partial() { printf 'cc-msg: delivery may be partial or unconfirmed: %s; do not resend automatically\n' "$1" >&2; exit 4; }
busy() { printf 'REFUSE: another relay is in progress; no target input was sent; safe to retry after the condition clears\n' >&2; exit 5; }
refuse_draft() { [ "${relay_operator_ready:-0}" != 1 ] || partial "operator replacement stopped after clear: $1"; printf 'cc-msg: target %s has %s; no target input was sent; safe to retry after the condition clears\n' "$1" "${2:-an unproven composer state}" >&2; exit 5; }
usage() {
  cat >&2 <<'EOF'
usage: cc-msg.sh [--operator|-O] <text>
       CC_MSG_SESSION=<session> CC_MSG_WINDOW=<name-or-index> [CC_MSG_PANE=%<id>] [CC_MSG_EXACT=1] cc-msg.sh <text>
       CC_MSG_SESSION=<session> CC_MSG_WINDOW=<window> cc-msg.sh --clear-draft --expect <exact-text>

Clear mode requires an exact 1–16 character ASCII draft; refusal exits 8.
Brackets, attachments, edge spaces and selected text are refused.
It clears only, never sends a message or queues a clear, and logs to the inbox.

CC_MSG_PANE is optional.  When a named window has multiple panes, set it to
one numeric tmux pane id (for example %46).  The id must still belong to the
declared CC_MSG_SESSION and CC_MSG_WINDOW; it never bypasses that binding.
Sender labels come from process ancestry and a fresh pane identity check.
Unidentified senders use a neutral relay label; CC_MSG_FROM is ignored.
CC_MSG_EXACT=1 sends the text without the sender label, only to a pane whose
folder is an agentic audit seat (/private/tmp/review-protocol-*-audit-r*-agentic-*-cli).
EOF
}

if [ "${1:-}" = --help ] || [ "${1:-}" = -h ]; then
  usage
  exit 0
fi

TIMEOUT_BIN="${TIMEOUT_BIN:-$(command -v timeout || command -v gtimeout || true)}"
TMUX_BIN="${TMUX_BIN:-tmux}"
TMUX_TIMEOUT_SECONDS="${TMUX_TIMEOUT_SECONDS:-1}"
TMUX_TIMEOUT_KILL_AFTER="${TMUX_TIMEOUT_KILL_AFTER:-1}"
RELAY_LOCK_ROOT="${TMUX_RELAY_LOCK_ROOT:-/private/tmp/tmux-$(id -u)/relay-locks}"
LOCK_BIN="${TMUX_RELAY_LOCK_BIN:-/usr/bin/shlock}"
relay_lock=
[ -n "$TIMEOUT_BIN" ] || fail 'timeout or gtimeout is required'
[ -x "$LOCK_BIN" ] || fail 'shlock is required'

relay_script="${BASH_SOURCE[0]}"
while [ -L "$relay_script" ]; do
  relay_script_dir="$(cd -P "$(dirname "$relay_script")" && pwd)" || fail 'cannot resolve relay tool directory'
  relay_link="$(readlink "$relay_script")" || fail 'cannot resolve relay tool path'
  case "$relay_link" in
    /*) relay_script="$relay_link" ;;
    *) relay_script="$relay_script_dir/$relay_link" ;;
  esac
done
relay_script_dir="$(cd -P "$(dirname "$relay_script")" && pwd)" || fail 'cannot resolve relay tool directory'
RELAY_INPUT_GUARD="$relay_script_dir/relay-input-guard"
[ -x "$RELAY_INPUT_GUARD" ] || fail 'relay input guard is required'

release_relay_lock() {
  [ -n "$relay_lock" ] || return 0
  if [ "$(cat "$relay_lock" 2>/dev/null)" = "$$" ]; then
    trash "$relay_lock" || printf 'relay: owned lock cleanup is unconfirmed; may remain at %s\n' "$relay_lock" >&2
  fi
  relay_lock=
}

acquire_relay_lock() {
  local socket identity key code
  socket="$(relay_display "$pane" '#{socket_path}')" || {
    code=$?
    [ "$code" = 75 ] && return 75
    return 1
  }
  [[ "$socket" = /* ]] || return 1
  relay_target_socket="$socket"
  identity="$(stat -Lf '%d:%i' "$socket" 2>/dev/null)" || return 1
  key="$(printf '%s' "$identity:$pane" | shasum -a 256 | awk '{print $1}')" || return 1
  umask 077
  mkdir -p "$RELAY_LOCK_ROOT" || return 1
  relay_lock="$RELAY_LOCK_ROOT/$key"
  "$LOCK_BIN" -f "$relay_lock" -p "$$" >/dev/null 2>&1 || {
    if [ -e "$relay_lock" ]; then relay_lock=; return 5; fi
    relay_lock=; return 1;
  }
}

trap release_relay_lock EXIT

request() {
  local deadline="$TMUX_TIMEOUT_SECONDS"
  [ "${1:-}" != if-shell ] || deadline=15
  "$TIMEOUT_BIN" -k "$TMUX_TIMEOUT_KILL_AFTER" "$deadline" "$TMUX_BIN" "$@"
  local code=$?
  case "$code" in
    124|137|143) [ "${1:-}" != if-shell ] || return 76; return 75 ;;
    *) return "$code" ;;
  esac
}

require_queue_binding() {
  [ -n "${CC_MSG_EXPECT_IDENTITY:-}" ] || return 0
  python3 "$relay_script_dir/cc-msg-queue" --check-binding "$CC_MSG_EXPECT_IDENTITY" || fail 'queued foreground process changed or cannot be proved'
}

require_empty_cc_input() {
  require_queue_binding
  local capture state state_after code cursor_x cursor_y in_mode
  if state="$(relay_display "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}')"; then
    :
  else
    code=$?
    [ "$code" = 75 ] && unresponsive
    fail "cannot query target input state for $pane"
  fi
  if [[ "$state" =~ ^([01]):([0-9]+):([0-9]+)$ ]]; then
    in_mode="${BASH_REMATCH[1]}"
    cursor_x="${BASH_REMATCH[2]}"
    cursor_y="${BASH_REMATCH[3]}"
  else
    fail "cannot determine target input state for $pane"
  fi
  [ "$in_mode" = 0 ] || refuse_copy "$pane"
  if capture="$(request capture-pane -p -e -t "$pane")"; then
    :
  else
    code=$?
    [ "$code" = 75 ] && unresponsive
    fail "cannot capture target input for $pane"
  fi
  if state_after="$(relay_display "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}')"; then
    :
  else
    code=$?
    [ "$code" = 75 ] && unresponsive
    fail "cannot recheck target input state for $pane"
  fi
  if [[ "$state_after" =~ ^([01]):([0-9]+):([0-9]+)$ ]]; then
    [ "${BASH_REMATCH[1]}" = 0 ] || refuse_copy "$pane"
  else
    fail "cannot recheck target input state for $pane"
  fi
  [ "$state_after" = "$state" ] || refuse_draft "$pane"
  relay_busy_preflight "$capture" "$cursor_y"
  printf '%s\n' "$capture" | "$RELAY_INPUT_GUARD" '❯' "$cursor_x" "$cursor_y" "$relay_verify_width" "$relay_sender_tier"
  code=$?
  case "$code" in
    0) relay_empty_cursor_x="$cursor_x"; relay_empty_cursor_y="$cursor_y"; relay_empty_capture="$capture"; return 0 ;;
    1) refuse_draft "$pane" "$(relay_refusal_reason "$capture")" ;;
    *)
      reason="$(relay_refusal_reason "$capture")"
      [ "$reason" = "a menu/overlay" ] && refuse_draft "$pane" "$reason"
      fail "cannot find CC prompt in target $pane"
      ;;
  esac
}

source "$relay_script_dir/relay-delivery.sh" || fail 'relay delivery module is required'

resolve_sender_label() {
  local sender sender_pane sender_session sender_window sender_pid sender_app identity code
  FROM=relay
  sender="$("$relay_script_dir/relay-sender-label" "$$" "$list_file")" || return 0
  [ -n "$sender" ] || return 0
  read -r sender_pane sender_session sender_window sender_pid sender_app <<< "$sender"
  case "$sender_app" in
    claude|codex|agy|gemini) ;;
    *) return 0 ;;
  esac
  if identity="$(request display-message -p -t "$sender_pane" '#{pane_id} #{session_name} #{window_name} #{pane_pid} #{pane_dead}')"; then
    [ "$identity" = "$sender_pane $sender_session $sender_window $sender_pid 0" ] || return 0
  else
    code=$?
    [ "$code" = 75 ] && unresponsive
    return 0
  fi
  FROM="$sender_app ($sender_session:$sender_window)"
}

[ -x "$relay_script_dir/relay-sender-label" ] || fail 'relay sender resolver is required'
target_session="${CC_MSG_SESSION:-}"
target_window="${CC_MSG_WINDOW:-}"
target_pane="${CC_MSG_PANE:-}"
case "$target_session" in
  ''|*[!A-Za-z0-9_-]*) fail 'CC_MSG_SESSION is required and may contain only letters, digits, underscores, or hyphens' ;;
esac
case "$target_window" in
  ''|*[!A-Za-z0-9_-]*) fail 'CC_MSG_WINDOW is required and may contain only letters, digits, underscores, or hyphens' ;;
esac
case "$target_pane" in
  '') ;;
  %*)
    case "${target_pane#%}" in
      ''|*[!0-9]*) fail 'CC_MSG_PANE, when set, must be a numeric tmux pane id such as %46' ;;
    esac
    ;;
  *) fail 'CC_MSG_PANE, when set, must be a numeric tmux pane id such as %46' ;;
esac
if [ "$#" -gt 0 ]; then
  msg="$(printf '%s' "$*" | "$relay_payload_guard" normalize)" || fail 'invalid message; printable UTF-8 is required'
else
  msg="$("$relay_payload_guard" normalize)" || fail 'invalid stdin message; printable UTF-8 is required'
fi
[ -n "$msg" ] || fail 'empty message; refuse'
[ -n "${TMUX:-}" ] || fail 'TMUX is not set; refuse'

list_file="$(mktemp "${TMPDIR:-/tmp}/cc-msg-list.XXXXXX")" || fail 'cannot create request scratch file'
if request list-panes -a -F '#{pane_id} #{session_name} #{window_name} #{pane_current_command} #{pane_pid} #{pane_dead}' > "$list_file"; then
  :
else
  code=$?
  trash "$list_file" || printf 'relay: list scratch cleanup is unconfirmed; may remain at %s\n' "$list_file" >&2
  list_file=
  [ "$code" = 75 ] && unresponsive
  fail 'cannot query tmux panes; refuse'
fi
if [ -n "$target_pane" ]; then
  target_count="$(awk -v session="$target_session" -v window="$target_window" -v pane="$target_pane" '("" $1) == ("" pane) && ("" $2) == ("" session) && ("" $3) == ("" window) { n++ } END { print n + 0 }' "$list_file")"
  pane="$(awk -v session="$target_session" -v window="$target_window" -v pane="$target_pane" '("" $1) == ("" pane) && ("" $2) == ("" session) && ("" $3) == ("" window) { print $1 }' "$list_file")"
  command_name="$(awk -v session="$target_session" -v window="$target_window" -v pane="$target_pane" '("" $1) == ("" pane) && ("" $2) == ("" session) && ("" $3) == ("" window) { print $4 }' "$list_file")"
else
  target_count="$(awk -v session="$target_session" -v window="$target_window" '("" $2) == ("" session) && ("" $3) == ("" window) { n++ } END { print n + 0 }' "$list_file")"
  pane="$(awk -v session="$target_session" -v window="$target_window" '("" $2) == ("" session) && ("" $3) == ("" window) { print $1 }' "$list_file")"
  command_name="$(awk -v session="$target_session" -v window="$target_window" '("" $2) == ("" session) && ("" $3) == ("" window) { print $4 }' "$list_file")"
fi
resolve_sender_label
resolve_relay_sender_tier
[ "${CC_MSG_QUEUE_STRICT:-}" != 1 ] || relay_sender_tier=strict
trash "$list_file" || printf 'relay: list scratch cleanup is unconfirmed; may remain at %s\n' "$list_file" >&2
list_file=
case "$target_count" in
  0)
    if [ -n "$target_pane" ]; then
      fail "target pane $target_pane is not in $target_session:$target_window; refuse"
    fi
    fail "no target window $target_session:$target_window; refuse"
    ;;
  1) ;;
  *) fail "target window $target_session:$target_window is ambiguous; set CC_MSG_PANE to one pane id in that window; refuse" ;;
esac
case "$command_name" in
  fish|bash|zsh|sh|dash|tmux) fail "pane $pane is running '$command_name', not Claude Code; refuse" ;;
esac

if [ -n "${CC_MSG_EXPECT_PID:-}" ]; then
  expected_pid="$(request display-message -p -t "$pane" '#{pane_pid}')" || fail 'cannot revalidate queued target process'
  [ "$expected_pid" = "$CC_MSG_EXPECT_PID" ] || fail 'queued target process changed'
fi

relay_target_window="$target_window"
relay_require_route
relay_glyph="❯"
if acquire_relay_lock; then
  :
else
  code=$?
  case "$code" in
    5) busy ;;
    75) unresponsive ;;
    *) fail "cannot establish target relay lock" ;;
  esac
fi
payload="$FROM: $msg"
case "${CC_MSG_EXACT:-}" in
  '') ;;
  1)
    if seat_path="$(relay_display "$pane" '#{pane_current_path}')"; then
      :
    else
      code=$?
      [ "$code" = 75 ] && unresponsive
      fail "cannot read target folder for exact delivery to $pane"
    fi
    [[ "$seat_path" =~ ^/private/tmp/review-protocol-[A-Za-z0-9._-]+-audit-r[0-9]+-agentic-[A-Za-z0-9._-]+-cli$ ]] || fail "CC_MSG_EXACT=1 is only for agentic audit seats; target folder is not one"
    case "${msg:0:1}" in
      '/'|'!'|'#') fail 'exact message starts with "/", "!" or "#", which the receiving CLI would treat as a command; rephrase and resend' ;;
    esac
    payload="$msg"
    ;;
  *) fail 'CC_MSG_EXACT, when set, must be 1' ;;
esac
relay_auto_archive=1
prepare_payload "$payload"
payload="$relay_prepared_payload"
relay_operator_prepare
require_empty_cc_input
sleep 0.04
require_empty_cc_input

require_queue_binding
if atomic_text "$payload"; then
  :
else
  code=$?
  case "$code" in
    2) refuse_copy "$pane" ;;
    3) refuse_draft "$pane" "an unproven composer state" ;;
    6) fail "target identity changed before paste" ;;
    7) fail "cannot prepare literal payload before paste" ;;
    75) unresponsive ;;
    *) partial 'literal delivery outcome is unknown' ;;
  esac
fi
verify_payload
sleep 0.04
verify_payload
if [ -n "${CC_MSG_EXPECT_IDENTITY:-}" ]; then
  python3 "$relay_script_dir/cc-msg-queue" --check-binding "$CC_MSG_EXPECT_IDENTITY" || partial 'queued foreground process changed after paste'
fi
if atomic_enter; then
  :
else
  code=$?
  case "$code" in
    2) partial "target $pane entered copy mode after literal delivery; Enter was not sent" ;;
    75) unresponsive ;;
    *) partial 'Enter delivery outcome is unknown' ;;
  esac
fi
printf 'cc-msg: delivered to %s (%s:%s); complete composer verified (not an acknowledgment)\n' "$pane" "$target_session" "$target_window"
