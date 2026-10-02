#!/usr/bin/env bash
# path: ~/.config/tmux/tools/relay-delivery.sh
# description: Bracketed relay transport with complete composer verification before submission.
# patched: reserve a Claude cursor cell before literal payload delivery
# date: 2026-10-02T04:00:00Z

relay_payload_file=
relay_payload_dir=
relay_payload_buffer=
relay_server_unresponsive=0
relay_input_attempted=0
relay_payload_guard="$relay_script_dir/relay-payload-guard"
[ -x "$relay_payload_guard" ] || fail 'relay payload guard is required'
command -v trash >/dev/null 2>&1 || fail 'trash is required for relay scratch cleanup'
for relay_timeout_value in "$TMUX_TIMEOUT_SECONDS" "$TMUX_TIMEOUT_KILL_AFTER"; do
  [[ "$relay_timeout_value" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v duration="$relay_timeout_value" 'BEGIN { exit !(duration > 0) }' || fail 'tmux timeouts must be positive numbers of seconds'
done

relay_cleanup() {
  local code=0
  if [ -n "$relay_payload_buffer" ] && [ "$relay_server_unresponsive" = 0 ]; then
    request delete-buffer -b "$relay_payload_buffer" >/dev/null 2>&1 || code=$?
  fi
  if [ -n "$relay_payload_dir" ]; then
    trash "$relay_payload_dir" >/dev/null 2>&1 ||
      printf 'relay: payload scratch cleanup is unconfirmed; may remain at %s\n' "$relay_payload_dir" >&2
    relay_payload_dir=
  fi
  if [ -n "${list_file:-}" ]; then
    trash "$list_file" >/dev/null 2>&1 ||
      printf 'relay: list scratch cleanup is unconfirmed; may remain at %s\n' "$list_file" >&2
  fi
  release_relay_lock
  [ "$code" = 75 ] && unresponsive
  return 0
}
trap relay_cleanup EXIT

relay_interrupted() {
  trap - INT TERM PIPE
  [ "$relay_input_attempted" = 0 ] || partial "interrupted by $1; target input may remain"
  fail "interrupted by $1; no target input was sent"
}
trap 'relay_interrupted SIGINT' INT
trap 'relay_interrupted SIGTERM' TERM
trap 'relay_interrupted SIGPIPE' PIPE

prepare_payload() {
  local dimensions code bytes width height
  relay_payload_dir="$(mktemp -d "${TMPDIR:-/tmp}/relay-payload.XXXXXX")" || fail 'cannot create payload scratch directory'
  relay_payload_file="$relay_payload_dir/payload"
  printf '%s' "$1" > "$relay_payload_file" || fail 'cannot write payload scratch file'
  "$relay_payload_guard" validate "$relay_payload_file" || fail 'payload must be printable UTF-8 without control or format characters'
  if dimensions="$(request display-message -p -t "$pane" '#{pane_width}:#{pane_height}:#{pane_dead}:#{session_name}:#{window_name}:#{pane_pid}:#{pane_current_command}')"; then
    :
  else
    code=$?
    [ "$code" = 75 ] && unresponsive
    fail 'cannot validate target identity and dimensions'
  fi
  [[ "$dimensions" =~ ^([0-9]+):([0-9]+):0:$target_session:$relay_target_window:([0-9]+):([A-Za-z0-9_.+-]+)$ ]] || fail 'target identity changed or target pane is dead'
  [ "${BASH_REMATCH[4]}" = "$command_name" ] || fail 'target process changed during resolution'
  width="${BASH_REMATCH[1]}"
  height="${BASH_REMATCH[2]}"
  relay_target_pid="${BASH_REMATCH[3]}"
  relay_target_command="${BASH_REMATCH[4]}"
  relay_verify_width="$width"
  relay_verify_height="$height"
  bytes="$(LC_ALL=C wc -c < "$relay_payload_file" | tr -d ' ')"
  [ "$width" -gt 4 ] && [ "$height" -gt 6 ] || fail 'target pane is too small to verify delivery'
  [ "$bytes" -le "$(((width - 2) * (height - 6)))" ] || fail 'payload exceeds visible verification capacity; send a short file reference instead'
  "$relay_payload_guard" capacity "$relay_payload_file" "$width" "$relay_glyph" || fail 'payload would wrap and cannot be verified byte for byte; send a short file reference instead'
}

relay_atomic() {
  local deliver=$1 blocked receipt code identity guarded command_file
  blocked="display-message -p -t $pane '__RELAY_REFUSED__:#{pane_in_mode}:#{pane_dead}:#{session_name}:#{window_name}'"
  identity="#{&&:#{==:#{session_name},$target_session},#{&&:#{==:#{window_name},$relay_target_window},#{&&:#{==:#{pane_dead},0},#{&&:#{==:#{pane_pid},$relay_target_pid},#{==:#{pane_current_command},$relay_target_command}}}}}"
  guarded="#{&&:$identity,#{==:#{pane_in_mode},0}}"
  guarded="#{&&:$guarded,#{&&:#{==:#{pane_width},$relay_verify_width},#{==:#{pane_height},$relay_verify_height}}}"
  if [ -n "${2:-}" ]; then
    guarded="#{&&:$guarded,#{&&:#{==:#{cursor_x},$2},#{==:#{cursor_y},$3}}}"
  fi
  if [ -n "${4:-}" ]; then
    command_file="$relay_payload_dir/send-keys-Enter.tmux"
    "$relay_payload_guard" tmux-enter "$4" "$relay_glyph" "$3" "$guarded" "$pane" "$deliver" "$blocked" > "$command_file" || return 1
    receipt="$(request source-file "$command_file")"
    code=$?
  elif receipt="$(request if-shell -F -t "$pane" "$guarded" "$deliver" "$blocked")"; then
    code=0
  else
    code=$?
  fi
  [ "$code" = 75 ] && return 75
  [ "$code" = 0 ] || return 1
  [ "$receipt" = __RELAY_DELIVERED__ ] && return 0
  [ "$receipt" = "__RELAY_REFUSED__:1:0:$target_session:$relay_target_window" ] && return 2
  [ "$receipt" = "__RELAY_REFUSED__:0:0:$target_session:$relay_target_window" ] && return 3
  printf 'relay: unexpected tmux delivery receipt: %s\n' "$receipt" >&2
  return 1
}

atomic_text() {
  local chunk_file code attempted=0 expected_x expected_y
  "$relay_payload_guard" chunks "$relay_payload_file" || return 1
  relay_payload_buffer="relay-$$-$(basename "$relay_payload_dir")"
  for chunk_file in "$relay_payload_dir"/chunk-*; do
    if request load-buffer -b "$relay_payload_buffer" "$chunk_file"; then
      :
    else
      code=$?
      [ "$code" = 75 ] && return 75
      return 1
    fi
    expected_x=; expected_y=
    [ "$attempted" = 0 ] && { expected_x="$relay_empty_cursor_x"; expected_y="$relay_empty_cursor_y"; }
    relay_input_attempted=1
    if relay_atomic "paste-buffer -p -d -t $pane -b $relay_payload_buffer ; display-message -p -t $pane __RELAY_DELIVERED__" "$expected_x" "$expected_y"; then
      attempted=1
    else
      code=$?
      [ "$code" = 2 ] && [ "$attempted" = 1 ] && return 1
      return "$code"
    fi
    sleep 0.1
  done
}

verify_payload() {
  # One coherent observation proves the current composer; a second full-pane
  # cycle converts harmless spinner/reconnect redraws into false exit 4s.
  # atomic_enter still rechecks the expected row, identity, and cursor.
  local state state_after capture code cursor_x cursor_y attempts=0 delay
  while [ "$attempts" -lt 24 ]; do
    attempts=$((attempts + 1))
    if state="$(request display-message -p -t "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}:#{pane_dead}:#{session_name}:#{window_name}:#{pane_width}:#{pane_height}:#{pane_pid}:#{pane_current_command}')"; then
      :
    else
      code=$?
      [ "$code" = 75 ] && unresponsive
      partial 'cannot query composer for payload verification'
    fi
    [[ "$state" =~ ^0:([0-9]+):([0-9]+):0:$target_session:$relay_target_window:$relay_verify_width:$relay_verify_height:$relay_target_pid:([A-Za-z0-9_.+-]+)$ ]] || partial "target identity, dimensions, or input mode changed during verification ($state)"
    [ "${BASH_REMATCH[3]}" = "$relay_target_command" ] || partial 'target process changed during verification'
    cursor_x="${BASH_REMATCH[1]}"
    cursor_y="${BASH_REMATCH[2]}"
    if capture="$(request capture-pane -p -e -t "$pane")"; then
      :
    else
      code=$?
      [ "$code" = 75 ] && unresponsive
      partial 'cannot capture composer for payload verification'
    fi
    if state_after="$(request display-message -p -t "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}:#{pane_dead}:#{session_name}:#{window_name}:#{pane_width}:#{pane_height}:#{pane_pid}:#{pane_current_command}')"; then
      :
    else
      code=$?
      [ "$code" = 75 ] && unresponsive
      partial 'cannot recheck composer for payload verification'
    fi
    if [ "$state" = "$state_after" ] && printf '%s\n' "$capture" | "$relay_payload_guard" compare "$relay_glyph" "$cursor_x" "$cursor_y" "$relay_payload_file" "$relay_verify_width"; then
      relay_verified_cursor_x="$cursor_x"
      relay_verified_cursor_y="$cursor_y"
      return 0
    fi
    # Briefly retry active redraws, then give a busy UI time to settle.
    if [ "$attempts" -lt 8 ]; then delay=0.05; else delay=0.15; fi
    sleep "$delay"
  done
  partial 'complete composer could not be verified; Enter was not sent'
}

atomic_enter() {
  # The payload row is checked inside relay_atomic.  If a redraw moves its
  # cursor between verification and source-file, re-observe coordinates and
  # retry only the known no-write refusal.
  local state code in_mode cursor_x cursor_y attempts=0 delay
  while [ "$attempts" -lt 24 ]; do
    attempts=$((attempts + 1))
    if state="$(request display-message -p -t "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}:#{pane_dead}:#{session_name}:#{window_name}:#{pane_width}:#{pane_height}:#{pane_pid}:#{pane_current_command}')"; then
      :
    else
      code=$?
      [ "$code" = 75 ] && return 75
      return 1
    fi
    [[ "$state" =~ ^([01]):([0-9]+):([0-9]+):0:$target_session:$relay_target_window:$relay_verify_width:$relay_verify_height:$relay_target_pid:([A-Za-z0-9_.+-]+)$ ]] || return 1
    in_mode="${BASH_REMATCH[1]}"
    cursor_x="${BASH_REMATCH[2]}"
    cursor_y="${BASH_REMATCH[3]}"
    [ "${BASH_REMATCH[4]}" = "$relay_target_command" ] || return 1
    [ "$in_mode" = 0 ] || return 2
    relay_verified_cursor_x="$cursor_x"
    relay_verified_cursor_y="$cursor_y"
    if relay_atomic "send-keys -t $pane Enter ; display-message -p -t $pane __RELAY_DELIVERED__" "$cursor_x" "$cursor_y" "$relay_payload_file"; then
      return 0
    else
      # Capture relay_atomic's status inside the conditional.  Reading $?
      # after a false `if` compound yields the compound's success status and
      # would incorrectly turn a refused Enter into SENT.
      code=$?
    fi
    [ "$code" = 3 ] || return "$code"
    if [ "$attempts" -lt 8 ]; then delay=0.05; else delay=0.15; fi
    sleep "$delay"
  done
  return 1
}
