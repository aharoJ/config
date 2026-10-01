#!/bin/bash
# path: ~/.config/tmux/tools/pane-watch/tests/suite.sh
# description: Check the complete offline watcher fixture suite.
# patched: retain the fixture suite and its dependencies in clean checkouts
# date: 2026-10-01
# Regression suite. Fixtures are physical-row pane captures; fixture geometry mirrors the real
# pane (prompt row, BLANK row, footer row) because every earlier suite got that wrong and stayed
# green while the tool was blind in production.
HERE="$(cd "$(dirname "$0")" && pwd)"
S="${1:-$HERE/../pane-watch.sh}"
pass=0; fail=0
ok(){ echo "PASS  $1"; pass=$((pass+1)); }
no(){ echo "FAIL  $1"; fail=$((fail+1)); [ -n "${2:-}" ] && echo "$2" | head -8 | sed 's/^/      /'; }
g(){  o=$("$HERE/run" "$S" "$1" ${4:-}); echo "$o" | grep -qE "$2" && ok "$3" || no "$3" "$o"; }
ng(){ o=$("$HERE/run" "$S" "$1" ${4:-}); echo "$o" | grep -q 'ARMED codex' || { no "$3 (never armed)" "$o"; return; }
      echo "$o" | grep -qE "$2" && no "$3 (forbidden)" "$o" || ok "$3"; }
cnt(){ o=$("$HERE/run" "$S" "$1" ${4:-}); n=$(echo "$o" | grep -c 'OPERATOR ACTION NEEDED'); [ "$n" = "$2" ] && ok "$3" || no "$3 (got $n want $2)" "$o"; }

echo "-- the alarm fires when it must --"
g startup_wait       'OPERATOR ACTION NEEDED' 'wait already in progress at arm time'
g phase_race         'OPERATOR ACTION NEEDED' 'question and idle land in different polls'
g stale_queued       'OPERATOR ACTION NEEDED' 'stale queue banner in scrollback'
g working_text       'OPERATOR ACTION NEEDED' '"Working" as prose, spinner gone'
g unmatched_decision 'OPERATOR ACTION NEEDED' 'menu choice, no question mark, no keyword'
g content_busy_static 'OPERATOR ACTION NEEDED' 'static "Working (" prose disbelieved'
g composer_request_erased 'OPERATOR ACTION NEEDED' 'request naming the prompt survives'
cnt dedup_repeat  2 'two distinct waits, identical wording'
cnt fast_backoff  2 'new turn not silenced by the old backoff'
g completed_idle 'completed, unacknowledged turn' 'completion labelled honestly, still alerts'
echo "-- the alarm stays quiet when it must --"
cnt empty_turn   0 'no alarm before the agent has replied'
cnt unknown_gap  0 'idle run resets across an unknown sample'
ng operator_false_fire 'my approval' 'operator text is not read as the agent request'
ng modal_no_anchor_content 'service modal' 'one modal phrase is not proof of a modal'
ng modal_two_on_one_row    'service modal' 'two markers on ONE row is not a modal'
ng modal_two_prose_rows    'service modal' 'two prose rows are not a modal'
ng stale_deep_restart 'OPERATOR ACTION NEEDED' 'stale composer deep in scrollback is not live UI'
ng padding_stale      'OPERATOR ACTION NEEDED' 'blank padding preserved, no scrollback bleed'
echo "-- losing the ability to observe is itself an event --"
g capture_failure  'WATCH COVERAGE LOST' 'capture failure loses coverage loudly'
g process_gone     'WATCH COVERAGE LOST' 'agent exited: coverage lost, not silent'
g stale_deep_restart 'WATCH COVERAGE LOST' 'replacement shell: coverage lost'
o=$("$HERE/run" "$S" capture_failure); echo "$o" | grep -q 'exit=3' && ok 'capture failure exits 3' || no 'capture failure exit code' "$o"
o=$("$HERE/run" "$S" process_gone);   echo "$o" | grep -q 'exit=2' && ok 'coverage loss exits 2' || no 'coverage loss exit code' "$o"
echo "-- identity, acknowledgment, geometry --"
g service_modal 'service modal' 'the real modal is recognised as itself'
ng service_modal 'WATCH COVERAGE LOST|OPERATOR ACTION NEEDED' 'the real modal is neither death nor a wait'
g ack_spent_observed 'OPERATOR ACTION NEEDED' 'acknowledgment spent when the turn moves on' --ack-current
g ack_unknown 'OPERATOR ACTION NEEDED' 'acknowledgment spends across a composerless turn' --ack-current
g ack_filter  'OPERATOR ACTION NEEDED' 'operator input containing prompt words still keys the turn' --ack-current
g real_geometry 'OPERATOR ACTION NEEDED' 'prompt, BLANK, footer: the real layout'
g real_geometry 'model=Fast off, gpt-5.6-sol medium' 'model parsed across the blank row'
g anchor_decoy 'question: • May I proceed with the migration' 'decoy prompt row does not steal the anchor'
n=$("$HERE/run" "$S" hot_same_new_turn | grep -c '^HOT:'); [ "$n" = "2" ] && ok 'same fault in a new turn is reported again' || no "same fault in new turn (got $n want 2)"
n=$("$HERE/run" "$S" hot_dash | grep -c '^HOT:'); [ "$n" = "1" ] && ok 'HOT text starting with a dash does not flood' || no "HOT dash (got $n want 1)"
o=$(PW_HEIGHT_DYNAMIC=1 "$HERE/run" "$S" resize_ack --ack-current); n=$(echo "$o" | grep -c 'OPERATOR ACTION NEEDED')
[ "$n" = "0" ] && ok 'acknowledgment survives a pane resize' || no "resize raised $n false alarms" "$o"
echo "===================================="
echo "pane-watch suite: pass=$pass fail=$fail"
[ "$fail" = "0" ] || exit 1
