#!/usr/bin/env bash
# path: ~/.config/tmux/tests/pane-watch-regression.sh
# description: Exercise watcher grammar and verified lock handoff with offline fixtures.
# patched: model server and pane identities for namespaced watcher locks
# date: 2026-10-01
# Black-box regression tests for the tracked pane-watch implementation. They emulate tmux and
# never touch a live pane. The fixture text is deliberately minimal but keeps the real physical
# prompt/blank/footer geometry.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WATCH="$HERE/../tools/pane-watch/pane-watch.sh"
TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
[ -x "$WATCH" ] || { echo "missing pane-watch: $WATCH" >&2; exit 1; }
[ -n "$TIMEOUT_BIN" ] || { echo "missing timeout or gtimeout" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/pane-watch-regression.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/fixtures"
watch_key="$(printf '%s' '/tmp/pane-watch-test.socket:999' | shasum -a 256 | awk '{print $1}')"
watch_lock="$TMP/pane-watch-locks/$watch_key-13"

cat > "$TMP/bin/tmux" <<'TMUX'
#!/usr/bin/env bash
case "${1:-}" in
  display-message)
    format="${!#}"
    pane_id='%13'
    [ "${PW_WRONG_FORMAT:-}" = "$format" ] && pane_id='%99'
    case "$format" in
      '#{pane_id}') echo "$pane_id" ;;
      '#{pane_id}:#{pane_height}:#{pid}:#{pane_pid}')
        if [ -n "${PW_CHANGE_AT:-}" ]; then
          count=$(cat "$PW_CHANGE_COUNT" 2>/dev/null || echo 0)
          count=$((count + 1))
          printf '%s\n' "$count" > "$PW_CHANGE_COUNT"
          [ "$count" -ge "$PW_CHANGE_AT" ] && { echo '%99:59:999:100'; exit 0; }
        fi
        echo "$pane_id:59:999:100" ;;
      '#{pane_id}:#{socket_path}') echo "$pane_id:/tmp/pane-watch-test.socket" ;;
      '#{pane_id}:#{pid}:#{pane_pid}') echo "$pane_id:999:100" ;;
      '#{pane_id} #{pane_dead} #{pane_current_command} #{session_name} #{window_name} #{pane_current_path}')
        echo "$pane_id 0 node TEST codex /tmp/project" ;;
      *) echo "unexpected display-message format: $format" >&2; exit 1 ;;
    esac
    ;;
  list-panes)
    if [ "${PW_MISSING_TARGET:-}" = 1 ] && [ "$3" = '%13' ]; then
      echo "can't find pane: %13" >&2; exit 1
    fi
    echo '%13' ;;
  capture-pane) cat "$PW_FIXTURE" ;;
  *) echo "unexpected fake tmux request: $*" >&2; exit 1 ;;
esac
TMUX
cat > "$TMP/bin/sleep" <<'SLEEP'
#!/usr/bin/env bash
case "${1:-}" in
  0.1) /bin/sleep 0.1 ;;
  *) exit 0 ;;
esac
SLEEP
chmod +x "$TMP/bin/tmux" "$TMP/bin/sleep"

write_fixture() {
  local name=$1 glyph=$2
  case "$name" in
    idle)
      printf '%s\n' \
        "$glyph submit this" \
        '• I have reached a destructive step. May I proceed?' \
        '' \
        "$glyph Ask Codex to do anything" \
        '' \
        '  Fast off · gpt-5.6-terra ultra · ~/p · Context 48% used · Main [default]' \
        > "$TMP/fixtures/$name-$glyph"
      ;;
    busy)
      printf '%s\n' \
        "$glyph submit this" \
        '• Working (12s · esc to interrupt)' \
        "$glyph Ask Codex to do anything" \
        '' \
        '  Fast off · gpt-5.6-terra ultra · ~/p · Context 48% used · Main [default]' \
        > "$TMP/fixtures/$name-$glyph"
      ;;
    queued)
      printf '%s\n' \
        "$glyph submit this" \
        'Messages to be submitted after next tool call' \
        "$glyph Ask Codex to do anything" \
        '' \
        '  Fast off · gpt-5.6-terra ultra · ~/p · Context 48% used · Main [default]' \
        > "$TMP/fixtures/$name-$glyph"
      ;;
    modal)
      printf '%s\n' \
        '• Explored' \
        '  Our systems are thinking a bit more about this request before responding.' \
        "$glyph 1. Retry with a faster model" \
        '  2. Dismiss and keep waiting' \
        '  No action is required. Codex will keep waiting, and this menu will close when the response is ready.' \
        > "$TMP/fixtures/$name-$glyph"
      ;;
  esac
}

run_watch() {
  local fixture=$1 output=$2
  shift 2
  set +e
  PATH="$TMP/bin:$PATH" TMPDIR="$TMP" PW_FIXTURE="$fixture" PW_POLL=0 \
    "$TIMEOUT_BIN" "${PW_WATCH_TIMEOUT:-1}" bash "$WATCH" --pane %13 --ui codex --ack-current "$@" > "$output" 2>&1
  local status=$?
  set -e
  case "$status" in 0|124|137|143) return 0 ;; *) cat "$output" >&2; return "$status" ;; esac
}

require() { grep -qE "$2" "$1" || { echo "missing $2 in $1" >&2; cat "$1" >&2; exit 1; }; }
forbidden() { grep -qE "$2" "$1" && { echo "unexpected $2 in $1" >&2; cat "$1" >&2; exit 1; } || true; }

for glyph in '›' '»'; do
  write_fixture idle "$glyph"
  idle_output="$TMP/$glyph-idle.out"
  run_watch "$TMP/fixtures/idle-$glyph" "$idle_output"
  require "$idle_output" 'ARMED codex'
  require "$idle_output" 'state=idle'
  forbidden "$idle_output" 'no operator turn boundary'

  for state in busy queued; do
    write_fixture "$state" "$glyph"
    state_output="$TMP/$glyph-$state.out"
    run_watch "$TMP/fixtures/$state-$glyph" "$state_output"
    require "$state_output" 'ARMED codex'
    require "$state_output" "state=$state"
  done

  write_fixture modal "$glyph"
  modal_output="$TMP/$glyph-modal.out"
  run_watch "$TMP/fixtures/modal-$glyph" "$modal_output"
  require "$modal_output" 'ARMED codex'
  require "$modal_output" 'state=modal'
  require "$modal_output" 'service modal'
  forbidden "$modal_output" 'WATCH COVERAGE LOST|OPERATOR ACTION NEEDED'
done

set +e
PATH="$TMP/bin:$PATH" TMPDIR="$TMP" PW_FIXTURE="$TMP/fixtures/idle-›" PW_MISSING_TARGET=1 PW_POLL=0 \
  "$TIMEOUT_BIN" 2 bash "$WATCH" --pane %13 --ui codex --ack-current > "$TMP/missing-target.out" 2>&1
status=$?
set -e
[ "$status" -eq 1 ] || { cat "$TMP/missing-target.out" >&2; exit 1; }
require "$TMP/missing-target.out" 'did not resolve to the reported pane'
forbidden "$TMP/missing-target.out" 'ARMED'

for format in '#{pane_id} #{pane_dead} #{pane_current_command} #{session_name} #{window_name} #{pane_current_path}' \
              '#{pane_id}:#{socket_path}' '#{pane_id}:#{pid}:#{pane_pid}' \
              '#{pane_id}:#{pane_height}:#{pid}:#{pane_pid}'; do
  output="$TMP/wrong-identity-$RANDOM.out"
  set +e
  PATH="$TMP/bin:$PATH" TMPDIR="$TMP" PW_FIXTURE="$TMP/fixtures/idle-›" PW_WRONG_FORMAT="$format" PW_POLL=0 \
    "$TIMEOUT_BIN" 2 bash "$WATCH" --pane %13 --ui codex --ack-current > "$output" 2>&1
  status=$?
  set -e
  [ "$status" -eq 1 ] || { cat "$output" >&2; exit 1; }
  require "$output" 'REFUSE:'
  forbidden "$output" 'ARMED'
done

set +e
PATH="$TMP/bin:$PATH" TMPDIR="$TMP" PW_FIXTURE="$TMP/fixtures/idle-›" PW_POLL=0 \
  PW_CHANGE_AT=4 PW_CHANGE_COUNT="$TMP/change-count" \
  "$TIMEOUT_BIN" 3 bash "$WATCH" --pane %13 --ui codex --ack-current > "$TMP/changed-pane.out" 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || { cat "$TMP/changed-pane.out" >&2; exit 1; }
require "$TMP/changed-pane.out" 'ARMED codex'
require "$TMP/changed-pane.out" 'WATCH COVERAGE LOST'
require "$TMP/changed-pane.out" 'Target server or pane process identity changed'

# A malformed live lock must never be deleted by --replace merely because its PID is alive.
mkdir -p "$watch_lock"
printf '%s\n' "$$" > "$watch_lock/pid"
set +e
PATH="$TMP/bin:$PATH" TMPDIR="$TMP" PW_FIXTURE="$TMP/fixtures/idle-»" PW_POLL=0 \
  "$TIMEOUT_BIN" 1 bash "$WATCH" --pane %13 --ui codex --replace > "$TMP/unverified-lock.out" 2>&1
status=$?
set -e
[ "$status" -eq 1 ] || { cat "$TMP/unverified-lock.out" >&2; exit 1; }
require "$TMP/unverified-lock.out" 'cannot be verified as this watcher'
[ -d "$watch_lock" ] || { echo 'unverified live lock was removed' >&2; exit 1; }
rm -rf "$watch_lock"

# A verified watcher receives TERM, releases its own lock, and is replaced without duplicate owners.
mkdir -p "$watch_lock" "$TMP/owner"
cat > "$TMP/owner/pane-watch.sh" <<'OWNER'
#!/usr/bin/env bash
lock=$1
trap 'rm -f "$lock/pid" "$lock/start" "$lock/ready"; rmdir "$lock"; exit 0' TERM
: > "$lock/ready"
while :; do :; done
OWNER
chmod +x "$TMP/owner/pane-watch.sh"
"$TMP/owner/pane-watch.sh" "$watch_lock" &
owner=$!
owner_start="$(ps -p "$owner" -o lstart= | awk '{$1=$1; print}')"
printf '%s\n' "$owner" > "$watch_lock/pid"
printf '%s\n' "$owner_start" > "$watch_lock/start"
for _ in $(seq 1 100); do
  [ -f "$watch_lock/ready" ] && break
  /bin/sleep 0.01
done
[ -f "$watch_lock/ready" ] || { echo 'test owner did not become ready' >&2; exit 1; }
handoff_output="$TMP/handoff.out"
PW_WATCH_TIMEOUT=7 run_watch "$TMP/fixtures/idle-»" "$handoff_output" --replace
wait "$owner" || true
require "$handoff_output" 'requesting a safe handoff'
require "$handoff_output" 'ARMED codex'
require "$handoff_output" 'state=idle'

echo 'pane-watch regression: PASS'
