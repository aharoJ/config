#!/usr/bin/env bash
# path: ~/.config/tmux/tests/relay-paste-collision-regression.sh
# description: Recheck a same-coordinate human draft staged at the guarded paste boundary.
set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
tmux_bin="${TMUX_BIN:-$(command -v tmux)}"
agy_bin="${AGY_BIN:-$HOME/.local/bin/agy}"
output_root="${RELAY_EVIDENCE_DIR:-${TMPDIR:-/tmp}}"
run="$(mktemp -d "$output_root/relay-paste-collision.XXXXXX")" || exit 90
socket="ccmsg-lab-private-$$"
trap '"$tmux_bin" -L "$socket" kill-server >/dev/null 2>&1 || true' EXIT
env -u NO_COLOR "$tmux_bin" -L "$socket" -f /dev/null new-session -d -s lab-race -n gemini -x 215 -y 57 "exec $agy_bin" || exit 90
pane="$("$tmux_bin" -L "$socket" list-panes -t '=lab-race:=gemini' -F '#{pane_id}')" || exit 90
ready=0
for i in {1..40}; do
  command_name="$("$tmux_bin" -L "$socket" display-message -p -t "$pane" '#{pane_current_command}')"
  if [ "$command_name" = agy ] && "$tmux_bin" -L "$socket" capture-pane -p -t "$pane" | rg -q '^>'; then ready=1; break; fi
  sleep 0.2
done
[ "$ready" = 1 ] || { printf 'Agy not ready; evidence: %s\n' "$run" >&2; exit 91; }
"$tmux_bin" -L "$socket" capture-pane -p -e -t "$pane" > "$run/before.ansi"
"$tmux_bin" -L "$socket" display-message -p -t "$pane" '#{pane_id} #{cursor_x}:#{cursor_y} #{pane_in_mode} #{pane_current_command}' > "$run/before.state"
cat > "$run/tmux-wrapper" <<'WRAPPER'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = if-shell ] && [ ! -e "$RELAY_RACE_RUN/staged" ]; then
  : > "$RELAY_RACE_RUN/staged"
  "$RELAY_RACE_TMUX_BIN" -L "$RELAY_RACE_SOCKET" send-keys -t "$RELAY_RACE_PANE" -l 'RT-RACE-HUMAN'
  "$RELAY_RACE_TMUX_BIN" -L "$RELAY_RACE_SOCKET" send-keys -t "$RELAY_RACE_PANE" Home
  "$RELAY_RACE_TMUX_BIN" -L "$RELAY_RACE_SOCKET" display-message -p -t "$RELAY_RACE_PANE" '#{cursor_x}:#{cursor_y}' > "$RELAY_RACE_RUN/staged.cursor"
  sleep 0.2
fi
exec "$RELAY_RACE_TMUX_BIN" -L "$RELAY_RACE_SOCKET" "$@"
WRAPPER
chmod +x "$run/tmux-wrapper"
RELAY_RACE_RUN="$run" RELAY_RACE_SOCKET="$socket" RELAY_RACE_PANE="$pane" RELAY_RACE_TMUX_BIN="$tmux_bin" TMUX_BIN="$run/tmux-wrapper" AGY_SEND_SESSION=lab-race \
  "$script_dir/../tools/agy-send-to" gemini RT-RACE-RELAY > "$run/relay.stdout" 2> "$run/relay.stderr"
relay_code=$?
printf '%s\n' "$relay_code" > "$run/relay.exit"
"$tmux_bin" -L "$socket" capture-pane -p -e -t "$pane" > "$run/after.ansi"
"$tmux_bin" -L "$socket" display-message -p -t "$pane" '#{pane_id} #{cursor_x}:#{cursor_y} #{pane_in_mode} #{pane_current_command}' > "$run/after.state"
[ -f "$run/staged" ] || { printf 'race trigger missed; evidence: %s\n' "$run" >&2; exit 1; }
if [ "$relay_code" != 5 ] && [ "$relay_code" != 1 ]; then printf 'unexpected exit %s; evidence: %s\n' "$relay_code" "$run" >&2; exit 1; fi
python3 - "$run/after.ansi" <<'ASSERT' || { printf 'draft changed; evidence: %s\n' "$run" >&2; exit 1; }
import pathlib, re, sys
raw = pathlib.Path(sys.argv[1]).read_text()
rows = [re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", row) for row in raw.splitlines()]
assert any(row == "> RT-RACE-HUMAN" for row in rows)
assert not any("RT-RACE-RELAY" in row for row in rows)
ASSERT
printf 'relay paste collision: PASS; evidence: %s\n' "$run"
