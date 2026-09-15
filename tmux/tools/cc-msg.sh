#!/usr/bin/env bash
set -uo pipefail

fail() { printf 'cc-msg: %s\n' "$1" >&2; exit 1; }
refuse_copy() { printf 'cc-msg: target %s is in copy mode; no target input was sent\n' "$1" >&2; exit 2; }
unresponsive() { printf 'cc-msg: tmux server is unresponsive; delivery state is unknown; do not resend automatically\n' >&2; exit 3; }
partial() { printf 'cc-msg: delivery may be partial or unconfirmed: %s; do not resend automatically\n' "$1" >&2; exit 4; }
busy() { printf 'cc-msg: another relay is in progress; no target input was sent by this invocation\n' >&2; exit 4; }

TIMEOUT_BIN="${TIMEOUT_BIN:-$(command -v timeout || command -v gtimeout || true)}"
TMUX_BIN="${TMUX_BIN:-tmux}"
TMUX_TIMEOUT_SECONDS="${TMUX_TIMEOUT_SECONDS:-1}"
TMUX_TIMEOUT_KILL_AFTER="${TMUX_TIMEOUT_KILL_AFTER:-1}"
RELAY_LOCK_ROOT="${TMUX_RELAY_LOCK_ROOT:-/private/tmp/tmux-$(id -u)/relay-locks}"
LOCK_BIN="${TMUX_RELAY_LOCK_BIN:-/usr/bin/shlock}"
relay_lock=
[ -n "$TIMEOUT_BIN" ] || fail 'timeout or gtimeout is required'
[ -x "$LOCK_BIN" ] || fail 'shlock is required'

release_relay_lock() {
  [ -n "$relay_lock" ] || return 0
  rm -f "$relay_lock"
  relay_lock=
}

acquire_relay_lock() {
  local socket identity key
  socket="${TMUX%%,*}"
  identity="$(stat -f '%d:%i' "$socket" 2>/dev/null || printf '%s' "$socket")"
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

octal_literal() {
  LC_ALL=C printf '%s' "$1" | od -An -v -tu1 | awk '
    BEGIN { printf "\"" }
    { for (i = 1; i <= NF; i++) printf "\\%03o", $i }
    END { printf "\"" }
  '
}

atomic_text() {
  local payload=$1 encoded blocked deliver receipt code cleanup_code payload_file= payload_buffer= bytes
  bytes="$(LC_ALL=C printf '%s' "$payload" | wc -c | tr -d ' ')"
  if [ "$bytes" -gt 3000 ]; then
    payload_file="$(mktemp "${TMPDIR:-/tmp}/cc-msg-payload.XXXXXX")" || return 1
    payload_buffer="cc-msg-$(basename "$payload_file")"
    LC_ALL=C printf '%s' "$payload" > "$payload_file" || { rm -f "$payload_file"; return 1; }
    if request load-buffer -b "$payload_buffer" "$payload_file"; then
      :
    else
      code=$?
      rm -f "$payload_file"
      return "$code"
    fi
    deliver="paste-buffer -d -t $pane -b $payload_buffer ; display-message -p -t $pane __CC_MSG_DELIVERED__"
  else
    encoded="$(octal_literal "$payload")" || return 1
    deliver="send-keys -t $pane -l -- $encoded ; display-message -p -t $pane __CC_MSG_DELIVERED__"
  fi
  blocked="display-message -p -t $pane __CC_MSG_REFUSED_COPY_MODE__"
  if receipt="$(request if-shell -F -t "$pane" '#{pane_in_mode}' "$blocked" "$deliver")"; then
    code=0
  else
    code=$?
  fi
  if [ -n "$payload_buffer" ]; then
    if request delete-buffer -b "$payload_buffer" >/dev/null 2>&1; then
      cleanup_code=0
    else
      cleanup_code=$?
    fi
    rm -f "$payload_file"
    [ "$cleanup_code" = 75 ] && code=75
  fi
  [ "$code" = 75 ] && return 75
  [ "$code" = 0 ] || return 1
  [ "$receipt" = __CC_MSG_DELIVERED__ ] && return 0
  [ "$receipt" = __CC_MSG_REFUSED_COPY_MODE__ ] && return 2
  return 1
}

atomic_enter() {
  local blocked deliver receipt code
  blocked="display-message -p -t $pane __CC_MSG_REFUSED_COPY_MODE__"
  deliver="send-keys -t $pane Enter ; display-message -p -t $pane __CC_MSG_DELIVERED__"
  if receipt="$(request if-shell -F -t "$pane" '#{pane_in_mode}' "$blocked" "$deliver")"; then
    code=0
  else
    code=$?
  fi
  [ "$code" = 75 ] && return 75
  [ "$code" = 0 ] || return 1
  [ "$receipt" = __CC_MSG_DELIVERED__ ] && return 0
  [ "$receipt" = __CC_MSG_REFUSED_COPY_MODE__ ] && return 2
  return 1
}

FROM="${CC_MSG_FROM:-codex}"
msg="$*"
[ -n "$msg" ] || msg="$(cat)"
msg="$(printf '%s' "$msg" | tr '\n\r\t' '   ' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')"
[ -n "$msg" ] || fail 'empty message; refuse'
[ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ] || fail 'not in tmux; refuse'

list_file="$(mktemp "${TMPDIR:-/tmp}/cc-msg-list.XXXXXX")" || fail 'cannot create request scratch file'
if request list-panes -a -F '#{pane_id} #{session_id}' > "$list_file"; then
  :
else
  code=$?
  rm -f "$list_file"
  [ "$code" = 75 ] && unresponsive
  fail 'cannot query tmux panes; refuse'
fi
sid="$(awk -v pane="$TMUX_PANE" '$1 == pane { n++; value=$2 } END { if (n == 1) print value }' "$list_file")"
rm -f "$list_file"
[ -n "$sid" ] || fail 'cannot resolve my own session from $TMUX_PANE; refuse'

target_file="$(mktemp "${TMPDIR:-/tmp}/cc-msg-target.XXXXXX")" || fail 'cannot create request scratch file'
if request list-panes -t "${sid}:=claude" -f '#{==:#{pane_index},1}' -F '#{pane_id} #{pane_current_command}' > "$target_file" 2>/dev/null; then
  :
else
  code=$?
  rm -f "$target_file"
  [ "$code" = 75 ] && unresponsive
  fail "no 'claude' window in my session; refuse"
fi
target="$(<"$target_file")"
rm -f "$target_file"
[ -n "$target" ] || fail "no 'claude' window in my session; refuse"
pane="${target%% *}"
command_name="${target#* }"
[ "$pane" != "$TMUX_PANE" ] || fail 'target pane is myself; refuse'
case "$command_name" in
  fish|bash|zsh|sh|dash|tmux) fail "pane $pane is running '$command_name', not Claude Code; refuse" ;;
esac

acquire_relay_lock || busy

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
sleep 1
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
sleep 2
if atomic_enter; then
  :
else
  code=$?
  case "$code" in
    2) partial "target $pane entered copy mode after earlier delivery; guard Enter was not sent" ;;
    75) unresponsive ;;
    *) partial 'guard Enter delivery outcome is unknown' ;;
  esac
fi
printf 'cc-msg: delivered to %s (%s:=claude)\n' "$pane" "$sid"
