# Relay guard landing gate

Every change to `tmux/tools/relay-input-guard` must prove that real empty composers still pass, as well as that drafts refuse. Run `bash tmux/tests/relay-live-capture-regression.sh --fixtures tmux/tests/fixtures/relay-must-accept.json` and `bash tmux/tests/relay-input-guard-regression.sh` before landing. The must-accept set contains raw `capture-pane -p -e` output and cursor metadata for the three 2026-10-01 exit-5 panes, fresh/post-turn config panes, and 40- and 19-column DeepSeek panes. The guard regression replays the real DeepSeek divider-shaped multiline draft in `relay-must-refuse.json` that caused a paste into unsent input. It also replays the 19-column pasted payload that previously failed verification.

Relay code must never trust a bare `tmux display-message -t` result: tmux may return exit 0 and another pane's data when the requested target has vanished. Include `#{pane_id}` in every targeted format and require it to equal the resolved pane ID, including paste and Enter receipts. A missing or mismatched identity is a refusal or an unknown delivery outcome according to whether input was already attempted.

Run `bash tmux/tests/relay-paste-collision-regression.sh` against a private interactive Agy fixture for the same-coordinate Home draft race, and `python3 tmux/tests/relay-duplicate-enter-regression.py` for the duplicate-history Enter condition. The first test preserves the staged human draft without relay bytes; the second requires an active-row check even when history contains the same payload.

`python3 tmux/tests/relay-paste-row-regression.py` checks the generated tmux condition against a private wrapped Codex hint: it accepts the original input rows, then refuses a changed continuation row at unchanged cursor coordinates. It also checks an empty Agy input row.

The same gate covers live Agy startup, post-turn, wide, 40-column and 19-column idle captures, plus Home-moved text and whitespace drafts. `agy-send-to` uses the same route and transport checks as the other relays; its exact session, window and optional pane routing are exercised by the guard regression.

The must-accept gate also includes the empty DeepSeek composer with the transient `Ctrl+Y to paste deleted text` status hint observed in blind live testing. Unknown hint text remains a refusal.

`relay-live-capture-regression.sh --manifest <tsv>` is the separate current Codex six-state gate. Run it only against detached `lab-*` sessions on a `ccmsg-lab-private-<pid>` server. It requires three idle and three draft states from actual Codex panes.
