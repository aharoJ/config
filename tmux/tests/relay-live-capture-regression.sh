#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'relay live capture regression: %s\n' "$1" >&2; exit 1; }
has_ansi() { printf '%s\n' "$1" | perl -ne '$found ||= /\e\[/; END { exit($found ? 0 : 1) }'; }
last_codex_prompt() { awk '/^[[:blank:]]*›/ { line=$0 } END { print line }'; }
last_cc_prompt() { awk '/^[[:blank:]]*❯/ { line=$0 } END { print line }'; }
strip_ansi() { perl -pe 's/\e\[[0-?]*[ -\/]*[@-~]//g'; }

codex_target="${1:-config:=tmux-codex}"
cc_target="${2:-libSZ:=claude}"
codex_styled="$(tmux capture-pane -p -e -t "$codex_target" -S -8)" || fail "cannot capture $codex_target"
codex_plain="$(tmux capture-pane -p -t "$codex_target" -S -8)" || fail "cannot capture $codex_target"
cc_styled="$(tmux capture-pane -p -e -t "$cc_target" -S -8)" || fail "cannot capture $cc_target"
cc_plain="$(tmux capture-pane -p -t "$cc_target" -S -8)" || fail "cannot capture $cc_target"

has_ansi "$cc_styled" || fail "CC styled capture has no ANSI sequence"
codex_prompt="$(printf '%s\n' "$codex_plain" | last_codex_prompt)"
codex_styled_prompt="$(printf '%s\n' "$codex_styled" | strip_ansi | last_codex_prompt)"
codex_styled_placeholder="$(printf '%s\n' "$codex_styled" | rg -a 'Ask Codex to do anything' | tail -n 1)"
has_ansi "$codex_styled_placeholder" || fail "Codex styled placeholder has no ANSI sequence"
[ "$codex_prompt" = '› Ask Codex to do anything' ] || fail "Codex placeholder was not selected"
[ "$codex_styled_prompt" = "$codex_prompt" ] || fail "Codex styled placeholder did not normalize to the plain capture"
cc_prompt="$(printf '%s\n' "$cc_plain" | last_cc_prompt)"
cc_styled_prompt="$(printf '%s\n' "$cc_styled" | strip_ansi | last_cc_prompt)"
printf '%s\n' "$cc_prompt" | perl -ne '$found ||= /\xc2\xa0/; END { exit($found ? 0 : 1) }' || fail "CC empty prompt has no NBSP"
cc_normalized="$(printf '%s\n' "$cc_prompt" | perl -pe 's/\xc2\xa0/ /g')"
[ "$cc_styled_prompt" = "$cc_prompt" ] || fail "CC styled prompt did not normalize to the plain capture"
printf '%s\n' "$cc_normalized" | grep -Eq '^[[:blank:]]*❯[[:blank:]]*$' || fail "CC empty prompt was not recognized"
cc_prompt_position="$(printf '%s\n' "$cc_plain" | awk '/^[[:blank:]]*❯/ { position=NR } END { print position + 0 }')"
[ "$cc_prompt_position" -gt 0 ] || fail "CC prompt position was not found"
cc_status="$(printf '%s\n' "$cc_plain" | awk '/^[[:blank:]]*❯/ { start=NR } { lines[NR]=$0 } END { for (i=start+1; i<=NR; i++) if (lines[i] ~ /(context|session|effort|permissions)/) { print lines[i]; exit } }')"
[ -n "$cc_status" ] || fail "CC capture has no status line under the composer"
cc_queued="$(printf '%s\n' "$cc_plain" | awk -v position="$cc_prompt_position" 'NR == position { print "Queued message: relay regression" } { print }')"
cc_queued_prompt="$(printf '%s\n' "$cc_queued" | last_cc_prompt | perl -pe 's/\xc2\xa0/ /g')"
[ "$cc_queued_prompt" = "$cc_normalized" ] || fail "CC queued-message capture changed the selected composer"
printf 'relay live capture regression: PASS\n'
