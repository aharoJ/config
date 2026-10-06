# Sanitized fixture provenance

Published captures use synthetic account identities and directories, with unrelated private transcript prose replaced. ANSI sequences, per-row cell widths, wrapping and cursor metadata are preserved. Manifest digests identify the sanitized published bytes; `/fixtures/` source identifiers are public labels, not links to raw evidence. Raw capture locations are not published. Synthetic-derived cases retain their distinct labels.

# Relay guard landing gate

Run `python3 tmux/tests/relay-enter-composer-regression.py <output-directory>` to exercise the actual final `relay_atomic` path on private detached terminals replaying real titled-Claude captures. Derived continuation drafts, boundary replacement, suffixes and moved cursors must send no Enter; valid composers and historical payload duplicates submit once. The final full-capture check retains before/after target metadata and a subsequent active-row check. Terminal changes after the final observation remain a residual race; the UI exposes no atomic snapshot-and-submit operation.

Run `python3 tmux/tests/relay-cc-title-regression.py <output-directory>` for real titled-Claude payload captures, a real ANSI empty composer with update/remote-control/shell indicators, and explicitly derived negative cases. Historical post-paste cursor positions are inferred from visible line endings and marked in metadata; the empty capture has recorded tmux cursor metadata. `relay-cc-title-real.json` records sanitized capture digests. `python3 tmux/tests/relay-real-capture-lab.py <output-directory>` replays those real screens on a private detached server and verifies exactly one Claude submission and an owned targeted Codex retry. Place a real empty Codex capture at `<output-directory>/codex-empty.ansi` before running the replay; terminal replay is transport coverage, not a live-model receipt.

`cc-msg` and `codex-send` default to the caller's tmux session and the `claude` or `codex` window. Explicit session and window overrides remain supported; numeric window indexes resolve to a name before the delivery identity is bound. Oversized messages are preserved under `~/desk/tmp/relay/` and delivered as a short `Read <path>` pointer.

Ordinary sends preserve drafts and queue safe busy/copy-mode refusals for automatic retry. Exit 6 means the queue owns delivery; do not resend. Retries remain bound to the original foreground process, stop after 30 minutes, and never replay uncertain delivery outcomes.

`--operator` / `-O` interrupts an active agent, clears its composer, and submits replacement text. Agents may use this mode only for an explicit operator cut, clear, delete, or erase-and-inject instruction. Agent-to-agent messages use the ordinary guarded path. Operator mode retains target identity and submission verification; an uncertain attempt after clearing is not automatically replayed.

Run `python3 tmux/tests/relay-defaults-regression.py` for private detached-server coverage of defaults, indexes, exact long-message preservation, draft-preserving retry, operator replacement of wrapped input with a cursor inside the draft, interruption of busy input, and explicit operator slash commands. Run `python3 tmux/tests/cc-msg-queue-regression.py` for persistence, target binding, and uncertain-outcome handling.

Every change to `tmux/tools/relay-input-guard` must prove that real empty composers still pass, as well as that drafts refuse. Run `bash tmux/tests/relay-live-capture-regression.sh --fixtures tmux/tests/fixtures/relay-must-accept.json` and `bash tmux/tests/relay-input-guard-regression.sh` before landing. The must-accept set contains sanitized `capture-pane -p -e` output and cursor metadata for the three 2026-10-01 exit-5 panes, fresh/post-turn config panes, and 40- and 19-column DeepSeek panes. The guard regression replays the sanitized DeepSeek divider-shaped multiline draft in `relay-must-refuse.json` that caused a paste into unsent input. It also replays the 19-column pasted payload that previously failed verification.

Relay code must never trust a bare `tmux display-message -t` result: tmux may return exit 0 and another pane's data when the requested target has vanished. Include `#{pane_id}` in every targeted format and require it to equal the resolved pane ID, including paste and Enter receipts. A missing or mismatched identity is a refusal or an unknown delivery outcome according to whether input was already attempted.

Run `bash tmux/tests/relay-paste-collision-regression.sh` against a private interactive Agy fixture for the same-coordinate Home draft race, and `python3 tmux/tests/relay-duplicate-enter-regression.py` for the duplicate-history Enter condition. The first test preserves the staged human draft without relay bytes; the second requires an active-row check even when history contains the same payload.

`python3 tmux/tests/relay-paste-row-regression.py` checks the generated tmux condition against a private wrapped Codex hint: it accepts the original input rows, then refuses a changed continuation row at unchanged cursor coordinates. It also checks an empty Agy input row.

The same gate covers live Agy startup, post-turn, wide, 40-column and 19-column idle captures, plus Home-moved text and whitespace drafts. `agy-send-to` uses the same route and transport checks as the other relays; its exact session, window and optional pane routing are exercised by the guard regression.

The must-accept gate also includes the empty DeepSeek composer with the transient `Ctrl+Y to paste deleted text` status hint observed in blind live testing. Unknown hint text remains a refusal.

`relay-live-capture-regression.sh --manifest <tsv>` is the separate current Codex six-state gate. Run it only against detached `lab-*` sessions on a `ccmsg-lab-private-<pid>` server. It requires three idle and three draft states from actual Codex panes.
