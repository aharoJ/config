#!/usr/bin/env bash
# path: ~/.config/tmux/tests/codex-new-chat-lab.sh
# description: Drive codex-new-chat against a fake Codex TUI on a private tmux server.
# date: 2026-10-03
set -u
lab=~/desk/lab/codex-new-chat-$$; mkdir -p "$lab/proj"
root="$(cd "$(dirname "$0")/.." && pwd)"
cp -R "$root/tools" "$lab/tools"
printf '#!/bin/sh\n[ $# -eq 3 ] && [ "$3" != lab-proof ] && exit 1\n[ $# -eq 2 ] && echo lab-proof\nexit 0\n' > "$lab/tools/codex-target-guard"
L=ccmsg-lab-private-$$
T() { tmux -L "$L" -f /dev/null "$@"; }
T new-session -d -s lab-cnc -n codex -x 200 -y 50 -c "$lab/proj" "node $root/tests/fixtures/codex-new-fake-tui.js ${START:-fresh} '~/desk/lab/codex-new-chat-$$/proj'"
sleep 1
sock=$(T display -p '#{socket_path}')
failn=0
go() { TMUX="$sock,1,0" CODEX_SEND_SESSION=lab-cnc "$lab/tools/codex-new-chat" codex; }
for i in $(seq 1 "${RUNS:-1}"); do out=$(go 2>&1); rc=$?; echo "run$i rc=$rc $out"; [ "$rc" = 0 ] || failn=1; done
T capture-pane -p -t lab-cnc:codex | grep -q "Context 0% used" || failn=1
T kill-server
trash "$lab"
exit "$failn"
