#!/usr/bin/env bash
# path: ~/.config/tmux/tests/relay-live-capture-regression.sh
# description: Verify guards against explicitly routed Codex and Claude terminal captures.
# patched: bind all capture requests to an explicitly private lab server
# date: 2026-10-01
set -euo pipefail

fail() { printf 'relay live capture regression: %s\n' "$1" >&2; exit 1; }
has_ansi() { printf '%s\n' "$1" | perl -ne '$found ||= /\e\[/; END { exit($found ? 0 : 1) }'; }
last_codex_prompt() { awk '/^[[:blank:]]*›/ { line=$0 } END { print line }'; }
last_cc_prompt() { awk '/^[[:blank:]]*❯/ { line=$0 } END { print line }'; }
strip_ansi() { perl -pe 's/\e\[[0-?]*[ -\/]*[@-~]//g'; }

root="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$root/tools/relay-input-guard"
[ -x "$guard" ] || fail 'relay input guard is not executable'
socket="${TMUX:-}"
socket="${socket%%,*}"
[[ "${socket##*/}" =~ ^ccmsg-lab-private-[0-9]+$ ]] || fail 'an explicitly private lab TMUX context is required'
lab_tmux() { tmux -L "${socket##*/}" -f /dev/null "$@"; }

codex_target="${1:-config:=tmux-codex}"
cc_target="${2:-libSZ:=claude}"
codex_state="$(lab_tmux display-message -p -t "$codex_target" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}')" || fail "cannot query $codex_target cursor"
cc_state="$(lab_tmux display-message -p -t "$cc_target" '#{pane_in_mode}:#{cursor_x}:#{cursor_y}')" || fail "cannot query $cc_target cursor"
[[ "$codex_state" =~ ^0:([0-9]+):([0-9]+)$ ]] || fail "Codex is not in a normal composer state: $codex_state"
codex_cursor_x="${BASH_REMATCH[1]}"
codex_cursor_y="${BASH_REMATCH[2]}"
[[ "$cc_state" =~ ^0:([0-9]+):([0-9]+)$ ]] || fail "CC is not in a normal composer state: $cc_state"
cc_cursor_x="${BASH_REMATCH[1]}"
cc_cursor_y="${BASH_REMATCH[2]}"
codex_styled="$(lab_tmux capture-pane -p -e -t "$codex_target")" || fail "cannot capture $codex_target"
codex_plain="$(lab_tmux capture-pane -p -t "$codex_target")" || fail "cannot capture $codex_target"
cc_styled="$(lab_tmux capture-pane -p -e -t "$cc_target")" || fail "cannot capture $cc_target"
cc_plain="$(lab_tmux capture-pane -p -t "$cc_target")" || fail "cannot capture $cc_target"

has_ansi "$codex_styled" || fail "Codex styled capture has no ANSI sequence"
has_ansi "$cc_styled" || fail "CC styled capture has no ANSI sequence"
codex_prompt="$(printf '%s\n' "$codex_plain" | last_codex_prompt)"
codex_styled_prompt="$(printf '%s\n' "$codex_styled" | strip_ansi | last_codex_prompt)"
[ -n "$codex_prompt" ] || fail "Codex prompt was not selected"
[ "$codex_styled_prompt" = "$codex_prompt" ] || fail "Codex styled placeholder did not normalize to the plain capture"
printf '%s\n' "$codex_styled" | "$guard" '›' "$codex_cursor_x" "$codex_cursor_y" || fail "Codex visible placeholder/suggestion was not accepted"
cc_prompt="$(printf '%s\n' "$cc_plain" | last_cc_prompt)"
cc_styled_prompt="$(printf '%s\n' "$cc_styled" | strip_ansi | last_cc_prompt)"
printf '%s\n' "$cc_prompt" | perl -ne '$found ||= /\xc2\xa0/; END { exit($found ? 0 : 1) }' || fail "CC empty prompt has no NBSP"
cc_normalized="$(printf '%s\n' "$cc_prompt" | perl -pe 's/\xc2\xa0/ /g')"
[ "$cc_styled_prompt" = "$cc_prompt" ] || fail "CC styled prompt did not normalize to the plain capture"
printf '%s\n' "$cc_normalized" | grep -Eq '^[[:blank:]]*❯[[:blank:]]*$' || fail "CC empty prompt was not recognized"
printf '%s\n' "$cc_styled" | "$guard" '❯' "$cc_cursor_x" "$cc_cursor_y" || fail "CC empty composer was not accepted"
cc_prompt_position="$(printf '%s\n' "$cc_plain" | awk '/^[[:blank:]]*❯/ { position=NR } END { print position + 0 }')"
[ "$cc_prompt_position" -gt 0 ] || fail "CC prompt position was not found"
cc_status="$(printf '%s\n' "$cc_plain" | awk '/^[[:blank:]]*❯/ { start=NR } { lines[NR]=$0 } END { for (i=start+1; i<=NR; i++) if (lines[i] ~ /(context|session|effort|permissions)/) { print lines[i]; exit } }')"
[ -n "$cc_status" ] || fail "CC capture has no status line under the composer"
cc_queued="$(printf '%s\n' "$cc_plain" | awk -v position="$cc_prompt_position" 'NR == position { print "Queued message: relay regression" } { print }')"
cc_queued_prompt="$(printf '%s\n' "$cc_queued" | last_cc_prompt | perl -pe 's/\xc2\xa0/ /g')"
[ "$cc_queued_prompt" = "$cc_normalized" ] || fail "CC queued-message capture changed the selected composer"
printf 'relay live capture regression: PASS\n'
