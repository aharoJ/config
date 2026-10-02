# Relay guard landing gate

Every change to `tmux/tools/relay-input-guard` must prove that real empty composers still pass, as well as that drafts refuse. Run `bash tmux/tests/relay-live-capture-regression.sh --fixtures tmux/tests/fixtures/relay-must-accept.json` and `bash tmux/tests/relay-input-guard-regression.sh` before landing. The must-accept set contains raw `capture-pane -p -e` output and cursor metadata for the three 2026-10-01 exit-5 panes, fresh/post-turn config panes, and 40- and 19-column DeepSeek panes. The guard regression replays the real DeepSeek divider-shaped multiline draft in `relay-must-refuse.json` that caused a paste into unsent input. It also replays the 19-column pasted payload that previously failed verification.

The same gate covers live Agy startup, post-turn, wide, 40-column and 19-column idle captures, plus Home-moved text and whitespace drafts. `agy-send-to` uses the same route and transport checks as the other relays; its exact session, window and optional pane routing are exercised by the guard regression.

`relay-live-capture-regression.sh --manifest <tsv>` is the separate current Codex six-state gate. Run it only against detached `lab-*` sessions on a `ccmsg-lab-private-<pid>` server. It requires three idle and three draft states from actual Codex panes.
