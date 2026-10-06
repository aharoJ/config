#!/usr/bin/env bash
# path: ~/.config/tmux/tools/relay-delivery.sh
# description: Bracketed relay transport with complete composer verification before submission.
# patched: preserve uniform draft-safe transport for every sender seat
# date: 2026-10-06

relay_payload_file=
relay_payload_dir=
relay_payload_buffer=
relay_server_unresponsive=0
relay_input_attempted=0
relay_paste_delivered=0
relay_enter_duplicate=0
relay_empty_capture=
relay_payload_guard="$relay_script_dir/relay-payload-guard"
relay_sender_tier=strict
relay_source_json=

relay_shell_join() {
  local argument escaped="'\\''"
  for argument in "$@"; do
    printf "'%s' " "${argument//\'/$escaped}"
  done
}

relay_route_command() {
  local arguments=(env "TMUX=$relay_target_socket,0,0" "TMUX_BIN=$TMUX_BIN" "TMUX_PANE=${TMUX_PANE:-}" "$TIMEOUT_BIN" -k 1 8 "$relay_script_dir/relay-route-guard" --caller "$$" --target-session "$target_session" --target-window "$relay_target_window")
  [ -z "${RELAY_MESSAGE_RECORD:-}" ] || arguments+=(--record "$RELAY_MESSAGE_RECORD")
  relay_shell_join "${arguments[@]}"
  printf ' >/dev/null'
}

relay_require_route() {
  local arguments=(--caller "$$" --target-session "$target_session" --target-window "$relay_target_window")
  [ -z "${RELAY_MESSAGE_RECORD:-}" ] || arguments+=(--record "$RELAY_MESSAGE_RECORD")
  if ! relay_source_json="$("$relay_script_dir/relay-route-guard" "${arguments[@]}")"; then
    [ "$relay_input_attempted" = 0 ] || partial 'route refused after input preparation; do not resend'
    fail 'route refused'
  fi
}

relay_display() {
  local expected=$1 format=$2 response
  response="$(request display-message -p -t "$expected" "#{pane_id}|$format")" || return $?
  [ "${response%%|*}" = "$expected" ] || return 1
  printf '%s\n' "${response#*|}"
}

resolve_relay_label() {
  local sender source_pane source_session source_window source_root source_app observed
  FROM=relay
  sender="$(printf '%s' "$relay_source_json" | python3 -c 'import json,sys
source=json.load(sys.stdin)
if source.get("app") in ("claude","codex","agy","gemini"):
 print(source["pane"],source["session"],source["window"],source["root"],source["app"])')" || fail 'verified source label is unavailable'
  [ -n "$sender" ] || return 0
  read -r source_pane source_session source_window source_root source_app <<< "$sender"
  observed="$(relay_display "$source_pane" '#{pane_id} #{session_name} #{window_name} #{pane_pid} #{pane_dead}')" || fail 'source changed before attribution'
  [ "$observed" = "$source_pane $source_session $source_window $source_root 0" ] || fail 'source changed before attribution'
  FROM="$source_app ($source_session:$source_window)"
}

relay_label_message() {
  resolve_relay_label
  if [ "${RELAY_OPERATOR:-0}" != 1 ]; then
    [ "$FROM" = relay ] || message="$FROM: $message"
    case "${message:0:1}" in
      '/'|'!') fail 'unattributed command-like text; use a bound source for a literal message' ;;
    esac
  fi
}

resolve_relay_sender_tier() {
  relay_sender_tier=strict
}

relay_busy_preflight() {
  local capture=$1 cursor_y=$2 code
  printf '%s\n' "$capture" | python3 -c 'import re,sys
glyph=sys.argv[1]
y=int(sys.argv[2])
rows=[re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", row) for row in sys.stdin.read().splitlines()]
if y >= len(rows) or not rows[y].lstrip().startswith(glyph):
    sys.exit(1)
if glyph == "›":
    previous=next((row.strip() for row in reversed(rows[max(0,y-4):y]) if row.strip()), "")
    sys.exit(0 if re.fullmatch(r"• Working \((?:[0-9]+h )?(?:[0-9]+m )?[0-9]+s [•·] esc to interrupt\)(?: · [1-9][0-9]* background terminals? running · /ps to view · /stop to close)?", previous) else 1)
if y == 0 or not re.fullmatch("─{8,}", rows[y-1].strip()):
    sys.exit(1)
if glyph == ">":
    previous=next((row.strip() for row in reversed(rows[max(0,y-3):y-1]) if row.strip()), "")
    spinner=bool(re.fullmatch(r"[⠁-⣿]  Generating\.\.\.", previous))
    footer=y+2 < len(rows) and rows[y+2].strip() == "esc to cancel"
    sys.exit(0 if spinner or footer else 1)
if glyph == "❯":
    preceding=[row.strip() for row in rows[max(0,y-4):y-1] if row.strip()]
    while preceding and re.match(r"^⎿\s*Tip:", preceding[-1]):
        preceding.pop()
    spinner=bool(preceding and re.fullmatch(r"[^\w\s] [^\r\n]*…(?: \([^\r\n]*\))?\s*", preceding[-1]))
    sys.exit(0 if spinner else 1)
sys.exit(2)' "$relay_glyph" "$cursor_y"
  code=$?
  case "$code" in
    0)
      refuse_draft "$pane" 'an agent busy state'
      ;;
    1) ;;
    *) refuse_draft "$pane" 'an unproven agent state' ;;
  esac
}

relay_refusal_reason() {
  local visible
  visible="$(printf '%s' "$1" | python3 -c 'import re,sys; print(re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", sys.stdin.read()))')"
  case "$visible" in
    *'press ctrl+c again to exit'*) printf '%s' 'an exit-warning overlay' ;;
    *'Generating…'*|*'esc to cancel'*|*'Thinking for'*) printf '%s' 'an agent busy state' ;;
    *'❯ (current)'*|*'/add-dir'*|*'/model         choose what model'*|*'/permissions   choose what Codex'*|*'Select a '*|*'Rewind'*) printf '%s' 'a menu/overlay' ;;
    *) printf '%s' 'a draft or unrecognized footer' ;;
  esac
}
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
  relay_prepared_payload="$1"
  relay_payload_dir="$(mktemp -d "${TMPDIR:-/tmp}/relay-payload.XXXXXX")" || fail 'cannot create payload scratch directory'
  relay_payload_file="$relay_payload_dir/payload"
  printf '%s' "$1" > "$relay_payload_file" || fail 'cannot write payload scratch file'
  "$relay_payload_guard" validate "$relay_payload_file" || fail 'payload must be printable UTF-8 without control or format characters'
  if dimensions="$(relay_display "$pane" '#{pane_width}:#{pane_height}:#{pane_dead}:#{session_name}:#{window_name}:#{pane_pid}:#{pane_current_command}')"; then
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
  if [ "$bytes" -gt "$(((width - 2) * (height - 6)))" ] || ! "$relay_payload_guard" capacity "$relay_payload_file" "$width" "$relay_glyph"; then
    [ "${relay_auto_archive:-0}" = 1 ] || fail 'payload would wrap and cannot be verified byte for byte; send a short file reference instead'
    relay_prepared_payload="$(python3 "$relay_script_dir/relay-archive" "$relay_payload_file")" || fail 'cannot archive oversized payload'
    printf '%s' "$relay_prepared_payload" > "$relay_payload_file" || fail 'cannot write archived payload pointer'
    "$relay_payload_guard" capacity "$relay_payload_file" "$width" "$relay_glyph" || fail 'target pane cannot fit the archive pointer'
  fi
}

relay_operator_prepare() {
  [ "${RELAY_OPERATOR:-0}" = 1 ] || return 0
  local condition receipt capture state keys attempts=0 code route_command nested
  relay_require_route
  require_queue_binding
  condition="#{&&:#{==:#{pane_id},$pane},#{&&:#{==:#{pane_pid},$relay_target_pid},#{&&:#{==:#{pane_current_command},$relay_target_command},#{&&:#{==:#{session_name},$target_session},#{&&:#{==:#{window_name},$relay_target_window},#{&&:#{==:#{pane_dead},0},#{==:#{pane_in_mode},0}}}}}}}"
  while [ "$attempts" -lt 20 ]; do
    require_queue_binding
    capture="$(request capture-pane -p -e -t "$pane")" || partial 'operator capture failed'
    state="$(relay_display "$pane" '#{cursor_y}')" || partial 'operator target changed'
    (relay_busy_preflight "$capture" "$state") >/dev/null 2>&1
    code=$?
    keys='C-e C-u'
    [ "$code" != 5 ] || keys="Escape $keys"
    relay_require_route
    relay_input_attempted=1
    route_command="$(relay_route_command)" || fail 'route refused'
    nested="$("$relay_payload_guard" tmux-nested "$pane" "$condition" "send-keys -t $pane $keys ; display-message -p -t $pane '__OPERATOR_SENT__:#{pane_id}'" "display-message -p -t $pane '__OPERATOR_CHANGED__:#{pane_id}'")" || fail 'cannot construct operator gate'
    receipt="$(request if-shell -t "$pane" "$route_command" "$nested" "display-message -p -t $pane '__OPERATOR_CHANGED__:#{pane_id}'")" || partial 'operator clear delivery is unknown'
    [ "$receipt" = "__OPERATOR_SENT__:$pane" ] || partial 'operator target changed during clear'
    sleep 0.1
    if [ "$relay_glyph" = '❯' ]; then
      (require_empty_cc_input) >/dev/null 2>&1
    elif [ "$relay_glyph" = '>' ]; then
      (require_empty_agy_input) >/dev/null 2>&1
    else
      (require_empty_codex_input) >/dev/null 2>&1
    fi
    code=$?
    [ "$code" = 0 ] && { relay_operator_ready=1; return 0; }
    case "$code" in
      3|4) partial 'operator clear could not be verified' ;;
    esac
    attempts=$((attempts + 1))
  done
  partial 'operator clear did not reach an empty composer'
}

relay_atomic() {
  local deliver=$1 blocked receipt code identity guarded command_file row_guard check_command nested route_command
  route_command="$(relay_route_command)" || return 1
  blocked="display-message -p -t $pane '__RELAY_REFUSED__:#{pane_id}:#{pane_in_mode}:#{pane_dead}:#{session_name}:#{window_name}'"
  identity="#{&&:#{==:#{pane_id},$pane},#{&&:#{==:#{session_name},$target_session},#{&&:#{==:#{window_name},$relay_target_window},#{&&:#{==:#{pane_dead},0},#{&&:#{==:#{pane_pid},$relay_target_pid},#{==:#{pane_current_command},$relay_target_command}}}}}}"
  guarded="#{&&:$identity,#{==:#{pane_in_mode},0}}"
  guarded="#{&&:$guarded,#{&&:#{==:#{pane_width},$relay_verify_width},#{==:#{pane_height},$relay_verify_height}}}"
  if [ -n "${2:-}" ]; then
    guarded="#{&&:$guarded,#{&&:#{==:#{cursor_x},$2},#{==:#{cursor_y},$3}}}"
  fi
  if [ -n "${4:-}" ]; then
    check_command="$(relay_shell_join "$relay_payload_guard" enter-composer "$relay_target_socket" "$pane" "$relay_glyph" "$2" "$3" "$4" "$relay_verify_width" "$relay_verify_height" "$relay_target_pid" "$relay_target_command" "$target_session" "$relay_target_window")" || return 1
    if [ "$relay_enter_duplicate" = 1 ]; then
      nested="$(relay_shell_join if-shell -F -t "$pane" "$guarded" "$deliver" "$blocked")" || return 1
    else
      nested="$("$relay_payload_guard" tmux-enter "$4" "$relay_glyph" "$3" "$guarded" "$pane" "$deliver" "$blocked")" || return 1
    fi
    receipt="$(request if-shell -t "$pane" "$route_command && $check_command" "$nested" "$blocked")"
    code=$?
  elif [ -n "${5:-}" ]; then
    if [ "$relay_glyph" = '❯' ]; then
      check_command="$("$relay_payload_guard" cc-prepaste-command "$relay_target_socket" "$pane" "$relay_glyph" "$2" "$3" "$relay_verify_width" "$relay_sender_tier" "$RELAY_INPUT_GUARD")" || return 7
      nested="$(relay_shell_join if-shell -F -t "$pane" "$guarded" "$deliver" "$blocked")" || return 7
      receipt="$(request if-shell -t "$pane" "$route_command && $check_command" "$nested" "$blocked")"
    else
      row_guard="$("$relay_payload_guard" tmux-paste "$5" "$relay_glyph" "$3")" || return 7
      guarded="#{&&:$guarded,$row_guard}"
      nested="$(relay_shell_join if-shell -F -t "$pane" "$guarded" "$deliver" "$blocked")" || return 7
      receipt="$(request if-shell -t "$pane" "$route_command" "$nested" "$blocked")"
    fi
    code=$?
  else
    nested="$(relay_shell_join if-shell -F -t "$pane" "$guarded" "$deliver" "$blocked")" || return 7
    receipt="$(request if-shell -t "$pane" "$route_command" "$nested" "$blocked")"
    code=$?
  fi
  [ "$code" = 75 ] && return 75
  [ "$code" != 76 ] || partial 'input gate deadline exceeded; delivery state unknown; do not resend'
  [ "$code" = 0 ] || return 1
  [ "$receipt" = "__RELAY_DELIVERED__:$pane" ] && return 0
  [ "$receipt" = "__RELAY_REFUSED__:$pane:1:0:$target_session:$relay_target_window" ] && return 2
  if [ "$receipt" = "__RELAY_REFUSED__:$pane:0:0:$target_session:$relay_target_window" ]; then
    local current
    current="$(relay_display "$pane" '#{pane_pid}:#{pane_current_command}:#{pane_width}:#{pane_height}')" || return 3
    [ "$current" = "$relay_target_pid:$relay_target_command:$relay_verify_width:$relay_verify_height" ] || return 6
    return 3
  fi
  [[ "$receipt" == __RELAY_REFUSED__:* ]] && return 6
  printf 'relay: unexpected tmux delivery receipt: %s\n' "$receipt" >&2
  return 1
}

atomic_text() {
  local chunk_file code attempted=0 expected_x expected_y relay_empty_capture_file
  "$relay_payload_guard" chunks "$relay_payload_file" || return 7
  relay_empty_capture_file="$relay_payload_dir/empty-capture"
  printf '%s\n' "$relay_empty_capture" > "$relay_empty_capture_file" || return 7
  relay_payload_buffer="relay-$$-$(basename "$relay_payload_dir")"
  for chunk_file in "$relay_payload_dir"/chunk-*; do
    if request load-buffer -b "$relay_payload_buffer" "$chunk_file"; then
      :
    else
      code=$?
      [ "$code" = 75 ] && return 75
      return 7
    fi
    expected_x=; expected_y=
    [ "$attempted" = 0 ] && { expected_x="$relay_empty_cursor_x"; expected_y="$relay_empty_cursor_y"; }
    relay_input_attempted=1
    if relay_atomic "paste-buffer -p -d -t $pane -b $relay_payload_buffer ; display-message -p -t $pane '__RELAY_DELIVERED__:#{pane_id}'" "$expected_x" "$expected_y" '' "$relay_empty_capture_file"; then
      attempted=1
      relay_paste_delivered=1
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
    if state="$(relay_display "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}:#{pane_dead}:#{session_name}:#{window_name}:#{pane_width}:#{pane_height}:#{pane_pid}:#{pane_current_command}')"; then
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
    if state_after="$(relay_display "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}:#{pane_dead}:#{session_name}:#{window_name}:#{pane_width}:#{pane_height}:#{pane_pid}:#{pane_current_command}')"; then
      :
    else
      code=$?
      [ "$code" = 75 ] && unresponsive
      partial 'cannot recheck composer for payload verification'
    fi
    if [ "$state" = "$state_after" ] && printf '%s\n' "$capture" | "$relay_payload_guard" compare "$relay_glyph" "$cursor_x" "$cursor_y" "$relay_payload_file" "$relay_verify_width"; then
      relay_enter_duplicate=0
      if printf '%s\n' "$capture" | "$relay_payload_guard" duplicate "$relay_payload_file" "$relay_glyph" "$cursor_y"; then
        relay_enter_duplicate=1
      fi
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
    if state="$(relay_display "$pane" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}:#{pane_dead}:#{session_name}:#{window_name}:#{pane_width}:#{pane_height}:#{pane_pid}:#{pane_current_command}')"; then
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
    if relay_atomic "send-keys -t $pane Enter ; display-message -p -t $pane '__RELAY_DELIVERED__:#{pane_id}'" "$cursor_x" "$cursor_y" "$relay_payload_file"; then
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
