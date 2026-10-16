# #p3x F11-F13: readiness fixed, real cycle passed

**GO for the authorized F11-F13 readiness slice.** The added renderer gate caused the timeout. It is removed, public relay selection is restored, and one fresh real Codex cycle passed end to end in 13.88 seconds. This resolves the readiness blocker in the F10 report. The earlier validator parity limits are unchanged and remain outside this brief; this is not a blanket certification of the full panel lane or a deployment action.

Base: `fffb147`. Task authority: `~/desk/tmp/relay/port/panel-f11.md`, hard cap F13. No validator, relay-core, timeout, caller, public-link, main-config or relay-stable implementation changes were made.

## Proven cause and parity correction

The live dispatcher (`~/.config/tmux/tools/panel-dispatch:478-487`) waits only until the pane's command is no longer a shell, checks cwd, resizes and captures once. Its `run()` at lines 128-133 strips command stdout. It does not interpret capture rows or require an idle composer to remain unchanged for two seconds.

F9 added that renderer condition and compared tmux's cursor coordinates with the stripped capture. This made the readiness condition stronger than the source and shifted capture row positions.

F11 used a fresh diagnostic seat from `panel-evidence/corrected/plain-1792091587555783000`, never an earlier claim. While the old gate was waiting, the owned seat was identity-checked as @378/%415, PID 1136, exact fresh seat cwd, current command `node`. It already satisfied the live dispatcher's non-shell rule. The captured before/after metadata were identical:

```
2|7|215|50|0|0|%415
```

The raw capture has a leading blank row. Its prompt is at actual row 7; stripping the capture shifts it to row 6. The native test ran the same predicate with that actual metadata and showed **raw empty=true, stripped empty=false**. The original gate then exhausted the requested 60-second deadline without Start and recovered its own seat. This is a reproduced capture/coordinate mismatch, not an inferred CLI startup delay.

Evidence under `~/desk/tmp/relay/port/panel-evidence/F11-F13/`: `F11-meta-before.txt`, `F11-raw.ansi`, `F11-meta-after.txt`, `F11-cause.log`, and `F11-diagnostic.log`. The fast regression uses the same real capture normalized to `/fixtures/seat`, its actual recorded metadata in `tests/fixtures/panel-codex-idle.meta`, and the existing composer classifier. It proves the row mismatch without retaining the deleted readiness policy.

The correction removes the added empty/stable-screen gate entirely. Native exec-image readiness still ensures the owned bootstrap has become the seat CLI; then the dispatcher performs the source's single capture after resize. No extra sleep, relaxed sender check, changed deadline or retry was introduced.

## Public relay behavior

The source dispatcher at lines 340-350 invokes the public role helpers with documented routing prefixes. `relay_start` now calls their public command names through the actual inherited PATH, replacing the panel binary's private `--surface` sender invocation. F11-F13 explicitly required using public commands as they are, including during any relay cutover.

At the successful run, public `codex-send-to` resolved to `~/.local/bin/codex-send-to` → `~/.local/share/relay-stable/tmux/tools/codex-send-to`. Before/after public pointers were unchanged; the observed wrapper SHA256 was `0604ae44132b57023fa2c38679499ff342fc0600a9d740ecfebd4f9c55e8bed0`. The public helper's current implementation was used as installed; it was not copied, changed, replaced with the candidate's sender, or bypassed. No public relay failure occurred in the successful cycle. `F12-public-before.txt` and `F12-public-after.txt` preserve the selections.

The native panel implementation still contains no interpreter bridge or inline executable code string. A public helper may retain its installed implementation language, as explicitly required by this slice's brief; this report does not claim every descendant of the public helper is Rust.

## Real cycle and caller environment

The candidate was copied into a private staged tools layout with native panel aliases through PATH. The runner began as a plain zsh pane in own `config-tt:p3x-test-f11` (@377/%414), inheriting actual TMUX `/private/tmp/tmux-501/default,1793,3` and TMUX_PANE `%414`. HOME was isolated for trust, private Codex home and relay evidence. Launch supplied the documented CODEX_SEND_SESSION prefix; no invented routing variable was injected.

Successful root: `~/desk/tmp/relay/port/panel-evidence/corrected/plain-1792091770979705000`. Candidate SHA256: `8a6339035ee36a0923ce72bf48410ccebc71f4dfc875e5c14db5276294a6f2f9`, identical in the build output and staged copy. The fresh seat was @379/%416, PID 11639; launch validates its exact session/window/pane/PID/cwd before and after delivery.

| Shape | Expected | Actual | Exit |
| --- | --- | --- | --- |
| Prepare with fresh first-attempt authority | Bound private seat and prepared receipt | Passed, 187 ms | 0 |
| Native launch and one public Start | One fresh CLI, exact target and delivered Start | Passed, 5,710 ms | 0 |
| Wait for native reads and final | Complete bound prompt/intake reads, one final | Passed, 7,237 ms | 0 |
| Collect | Candidate receipts bound to native/session/final evidence | Passed, 311 ms | 0 |
| Cleanup | Own window/process closure, trust retirement, evidence retained | Passed, 316 ms | 0 |

`parity.json` retains exact argv, stdout/stderr, caller environment and expected/actual exits for all five invocations. `F12-cycle.log` records the 13.88-second full-cycle pass. No earlier attempted claim or input was reused.

Public delivered record: `b9fefa41fc34482d92c2bf4f83a83547`, referenced and hash-bound by `interactive-batch/a-start.json`. The record has state `delivered`, exact Start text and source label, and target pane `%416`/PID `11639`. The preserved native transcript contains exactly **one Start user message and one final assistant message**.

`a-reads.json` binds complete literal `PROMPT.md` read at native call/result lines 25/28 and `intake.md` at lines 30/33. Session: `01a140fe-63db-7523-a5d4-d2ea46b212fe`. `a-final.md` SHA256 is `28cd1acdb2cbf78df8ae93b0e88ae62bae33d05c6b8e64da984527485781985b`. `collected.json` and `interactive-cleanup.json` bind those receipts; cleanup reports `window_closed`, `captured_processes_closed` and `trust_retired` all true. Fixture boundary/authority proofs remain test controls and do not certify a production panel's independence or qualified admission.

## Tests, grep and every Command::new

Default suite: **125 passed in 1.56 seconds**, fourteen explicit unit harness cases and six pane cases ignored by default. The one explicit real-cycle case passed; other model cycles were not launched. All-target clippy with warnings denied, formatter and staged diff checks pass. No broad test repetition followed the successful cycle.

The exact whole-crate command remains `git grep -n -i -E 'python|perl|fish|bash|/bin/sh' -- tmux/rust ':!*.md'`. Its six matches are literal external CLI `Bash` tool names in settings/argv/transcript decoding and a test, with no panel interpreter launch. Output and complete constructor search are published in `F11-F13/grep.txt` and `commands.txt` after staging all new files.

| Location | Concrete program |
| --- | --- |
| `src/panel_dispatch.rs:515` | Pinned `/opt/homebrew/bin/tmux`, current target `/opt/homebrew/Cellar/tmux/3.7c/bin/tmux`; observed namespace |
| `src/panel_dispatch.rs:577` | `/bin/ps`, existing owned custody snapshot |
| `src/panel_dispatch.rs:711` | Public PATH `cc-msg`, `codex-send-to` or `agy-send-to`; observed `~/.local/bin` links, with no fallback/private sender |
| `src/panel_launch.rs:264` | Kind-checked external CLI: PATH codex, PATH claude, HOME's pinned DeepSeek Claude, or PATH agy; same native exec as F10 |
| `src/panel_cleanup.rs:408` | PATH trash, observed `/usr/bin/trash` |
| Inherited `src/identity.rs:396,695` | Validated namespace tmux and pinned `/opt/homebrew/bin/tmux` |
| Inherited `src/runtime.rs:233` | Current native runtime, owned relay producer |
| `tests/panel_plain.rs:84` | Fixture aliases to copied native candidate |
| `tests/panel_plain.rs:205,478,495,508,532,609,623,628` | Pinned tmux, fixture-owned lifecycle/captures |
| `tests/support/panel_protocol.rs:978` | Fixture alias to copied native candidate; not run in this slice |
| `tests/support/private_server.rs:41`; `identity.rs:112,154`; `runtime.rs:167,464` | Current Rust test executable |
| `tests/support/private_server.rs:89,129,183,203`; `runtime.rs:773` | Pinned tmux, existing private fixtures |
| `tests/support/runtime.rs:87` | `/bin/cat`, existing owned-child control |

## Completion and remaining limits

F11 diagnosed the fresh idle seat with paired raw metadata/capture and a native proof. F12 made the parity correction, passed fast checks and completed exactly one successful fresh real cycle. F13 audited evidence, retired the diagnostic runner, committed and sent one completion message. Source/caller inventories and prior evidence remain discoverable; no unrelated work was undertaken.

The prior selected-schema pattern/normal-form parity limits remain unchanged in `p3x-panel-native-fix.md`; this slice did not authorize validator changes. Claude/DeepSeek/Agy interactive launches were not tested here. Public senders remain external and follow the public installation; the former private-sender registration assumptions are superseded by the explicit public-helper requirement. No overall panel deploy or broader cutover approval is implied.

Decision: **GO for F11-F13's readiness correction and requested real-cycle proof.** Final commit and added/removed counts are recorded in the external completion summary. Public links, relay-stable, main config, callers, memories and other panes/windows were untouched; own test seats and runner were retired. No subagents, headless Claude, relay workaround or input replay was used.
