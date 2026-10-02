#!/usr/bin/env bash
# path: ~/.config/tmux/tools/cc-msg.sh
# description: Deliver text to an explicitly selected agent with fail-closed payload verification.
# patched: pass verified pane width to the Claude composer boundary guard
# date: 2026-10-02T04:00:00Z
set -uo pipefail

fail() { printf 'cc-msg: %s\n' "$1" >&2; exit 1; }
refuse_copy() { printf 'cc-msg: target %s is in copy mode; no target input was sent\n' "$1" >&2; exit 2; }
unresponsive() { relay_server_unresponsive=1; printf 'cc-msg: tmux server is unresponsive; delivery state is unknown; do not resend automatically\n' >&2; exit 3; }
partial() { printf 'cc-msg: delivery may be partial or unconfirmed: %s; do not resend automatically\n' "$1" >&2; exit 4; }
busy() { printf 'cc-msg: another relay is in progress; no target input was sent by this invocation\n' >&2; exit 4; }
refuse_draft() { printf 'cc-msg: target %s has a draft; no target input was sent\n' "$1" >&2; exit 5; }
usage() {
  cat >&2 <<'EOF'
usage: CC_MSG_SESSION=<session> CC_MSG_WINDOW=<window> [CC_MSG_PANE=%<id>] cc-msg.sh <text>

CC_MSG_PANE is optional.  When a named window has multiple panes, set it to
one numeric tmux pane id (for example %46).  The id must still belong to the
declared CC_MSG_SESSION and CC_MSG_WINDOW; it never bypasses that binding.
Sender labels come from process ancestry and a fresh pane identity check.
Unidentified senders use a neutral relay label; CC_MSG_FROM is ignored.
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
  local socket identity key
  socket="${TMUX%%,*}"
  identity="$(stat -Lf '%d:%i' "$socket" 2>/dev/null || printf '%s' "$socket")"
  key="$(printf '%s' "$identity:$pane" | shasum -a 256 | awk '{print $1}')" || return 1
  umask 077
  mkdir -p "$RELAY_LOCK_ROOT" || return 1
  relay_lock="$RELAY_LOCK_ROOT/$key"
  "$LOCK_BIN" -f "$relay_lock" -p "$$" >/dev/null 2>&1 || { relay_lock=; return 1; }
}

trap release_relay_lock EXIT

request() {
  "$TIMEOUT_BIN" -k "$TMUX_TIMEOUT_KILL_AFTER" "$TMUX_TIMEOUT_SECONDS" "$TMUX_BIN" "$@"
  local code=$?
  case "$code" in
    124|137|143) return 75 ;;
    *) return "$code" ;;
  esac
}

require_empty_cc_input() {
  local capture state state_after code cursor_x cursor_y in_mode
  if state="$(request display-message -p -t "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}')"; then
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
  if state_after="$(request display-message -p -t "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}')"; then
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
  printf '%s\n' "$capture" | "$RELAY_INPUT_GUARD" '❯' "$cursor_x" "$cursor_y" "$relay_verify_width"
  code=$?
  case "$code" in
    0) relay_empty_cursor_x="$cursor_x"; relay_empty_cursor_y="$cursor_y"; return 0 ;;
    1) refuse_draft "$pane" ;;
    *) fail "cannot find CC prompt in target $pane" ;;
  esac
}

source "$relay_script_dir/relay-delivery.sh" || fail 'relay delivery module is required'

resolve_sender_label() {
  local sender sender_pane sender_session sender_window sender_pid sender_app identity code
  FROM=relay
  sender="$("$relay_script_dir/relay-sender-label" "$$" "$list_file")" || return 0
  [ -n "$sender" ] || return 0
  read -r sender_pane sender_session sender_window sender_pid sender_app <<< "$sender"
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
  target_count="$(awk -v session="$target_session" -v window="$target_window" -v pane="$target_pane" '$1 == pane && $2 == session && $3 == window { n++ } END { print n + 0 }' "$list_file")"
  pane="$(awk -v session="$target_session" -v window="$target_window" -v pane="$target_pane" '$1 == pane && $2 == session && $3 == window { print $1 }' "$list_file")"
  command_name="$(awk -v session="$target_session" -v window="$target_window" -v pane="$target_pane" '$1 == pane && $2 == session && $3 == window { print $4 }' "$list_file")"
else
  target_count="$(awk -v session="$target_session" -v window="$target_window" '$2 == session && $3 == window { n++ } END { print n + 0 }' "$list_file")"
  pane="$(awk -v session="$target_session" -v window="$target_window" '$2 == session && $3 == window { print $1 }' "$list_file")"
  command_name="$(awk -v session="$target_session" -v window="$target_window" '$2 == session && $3 == window { print $4 }' "$list_file")"
fi
resolve_sender_label
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

relay_target_window="$target_window"
relay_glyph="❯"
acquire_relay_lock || busy
prepare_payload "$FROM: $msg"
require_empty_cc_input

if atomic_text "$FROM: $msg"; then
  :
else
  code=$?
  case "$code" in
    2) refuse_copy "$pane" ;;
    75) unresponsive ;;
    *) partial 'literal delivery outcome is unknown' ;;
  esac
fi
verify_payload
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
