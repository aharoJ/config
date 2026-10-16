# #p3x panel fix: NO-GO / Divergence at 10 of 10

Historical budget-stop report. Angel subsequently approved the separate F1-F10 native fix slice. See `p3x-panel-native-fix.md` for the implemented native replacements and current F10 NO-GO; the old budget is not the current implementation blocker.

Angel chose native Rust replacements for the review-protocol checks and tai seat launch. The task brief is `~/desk/tmp/relay/port/panel-fix.md`. The existing implementation does not satisfy that decision: it still executes inline interpreter code. The earlier GO and claimed external-debt exception are withdrawn.

The fix brief explicitly says: "Continue your round count; the cap is 10. If you would exceed it, stop and send a Divergence report." The existing committed report (`p3x-panel-live.md`, originally line 110 at `45a92f7`) records the initial three rounds plus corrected rounds four through ten. There is no remaining implementation or verification round. This response records the divergence; it does not reset the counter or perform round eleven.

## Current implementation and required work

The runtime and tests are unchanged from `45a92f7` (`45a92f7a4d4e182907d6ef0cd61c780ba0bcb56a`). This response changes reports only. Both tools exist in the branch, but the lane must not be merged or deployed as compliant.

| Requirement | Current behavior | Result |
| --- | --- | --- |
| Native review-protocol checks | `panel_io.rs:382-399` assembles code from `panel_external.json` and invokes `python3 -P -B -c` | FAIL |
| Exact imported checks with source citations and real-artifact tests | The JSON bridge imports `agentic_consumers` and `ledger_schema`; no native replacement or per-check source/fixture matrix was implemented | Unfinished |
| Native tai launch, exact cwd/env/CLI and early ownership | `panel_dispatch.rs:849-855` builds inline functions and invokes `fish -l -c` | FAIL |
| No inline code execution | Both bridges execute inline strings | FAIL |
| Whole-crate interpreter grep, data included | Runtime hits in JSON and dispatcher; test hits also remain | FAIL |
| Re-run plain-pane matrix and real Codex lifecycle after replacement | No replacement exists and ten rounds have already been used | Not run |

The existing protocol call sites are `panel_dispatch.rs:220` (load/import), `panel_collect.rs:160` (seat schema), and `panel_dispatch.rs:1215` (context/evidence/pass-source validation). `panel_external.json:7-10` identifies the exact imported API calls that a future native port must trace through the read-only protocol checkout. No claim is made that simply parsing those artifacts preserves their checks.

The seat-launch replacement must remove the generated wrapper at `panel_dispatch.rs:849`, replace the tai source binding at line 297 with an appropriate native contract, and preserve window creation, trust, provider command/environment, and early own registration. The helper still emits an environment artifact for the old launcher (`panel_trust.rs:402`); that dependency also needs reconciliation. The native trust, evidence, ownership and cleanup work already present is not proof that the remaining launch path is native.

## Whole-crate gate

Read-only audit command, run against the unchanged implementation:

```
git grep -n -i -E 'python|perl|fish|bash|/bin/sh' -- tmux/rust ':!*.md'
```

Exit **0**, meaning matches were found. Exact output: `~/desk/tmp/relay/port/panel-evidence/corrected/fix-gate-before.txt`.

Runtime matches include `panel_external.json:2-5`, `panel_dispatch.rs:297`, and `panel_dispatch.rs:849`. The test matches are in `tests/panel_plain.rs:58,60,163,261,472`. Some matches identify protocol/tool data; the interpreter selections and executable inline launch string are actual runtime violations. The earlier source-only empty grep did not establish compliance.

## Every Command::new and actual program selection

The complete current source/test search is `~/desk/tmp/relay/port/panel-evidence/corrected/fix-commands-before.txt`. Paths below were inspected without starting an interpreter. PATH selections describe this reporting environment; callers can have another PATH, which is another reason these selections are not pinned native dependencies.

| Location | Concrete program or selection |
| --- | --- |
| `src/panel_io.rs:389` | `python3` from JSON; current PATH selects `~/.pyenv/shims/python3`, itself a shell shim into pyenv. The ultimate interpreter is selected by pyenv; not pinned or accepted. FORBIDDEN. |
| `src/panel_dispatch.rs:851` | `fish` from JSON; `/opt/homebrew/bin/fish` links to `/opt/homebrew/Cellar/fish/4.1.1/bin/fish`. FORBIDDEN. |
| `src/panel_dispatch.rs:523` | `/opt/homebrew/bin/tmux`, linking to `/opt/homebrew/Cellar/tmux/3.7c/bin/tmux`; namespace args may select the documented lab socket |
| `src/panel_dispatch.rs:585` | `/bin/ps`, process custody snapshot |
| `src/panel_dispatch.rs:719` | Current native executable from `source()`; dispatches cc-msg, codex-send-to or agy-send-to |
| `src/panel_cleanup.rs:408` | `trash` via PATH, currently `/usr/bin/trash`; existing owned-temp retirement |
| `src/identity.rs:396` | Namespace's validated executable, pinned `/opt/homebrew/bin/tmux` |
| `src/identity.rs:695` | `/opt/homebrew/bin/tmux`, default namespace attestation |
| `src/runtime.rs:233` | `std::env::current_exe()`, the native runtime; test builds select adjacent `angelstar-runtime` |
| `tests/panel_plain.rs:85` | PATH alias panel-dispatch or panel-seat-trust, both symlinked to that test fixture's copied `stage/tmux/tools/angelstar-runtime` |
| `tests/panel_plain.rs:213,488,505,518,542,619,633,638` | `/opt/homebrew/bin/tmux`, test-owned pane/window lifecycle |
| `tests/support/private_server.rs:41` | Current Rust test executable, private-server supervisor |
| `tests/support/private_server.rs:89,129,183,203` | `/opt/homebrew/bin/tmux`, private fixture server |
| `tests/support/identity.rs:112,154` | Current Rust test executable, identity controls |
| `tests/support/runtime.rs:87` | `/bin/cat`, existing child-lifecycle control |
| `tests/support/runtime.rs:167,464` | Current Rust test executable, runtime fixture actors |
| `tests/support/runtime.rs:773` | `/opt/homebrew/bin/tmux`, private attached-client fixture |

The trust module itself starts no subprocess. No interpreters or provider CLIs were started for this response.

## Historical parity and tests, not re-run

Exact argv, caller environments, expected/actual exits and outputs for the previous implementation remain in `~/desk/tmp/relay/port/panel-evidence/corrected/`, indexed by `final-all.log`. The historical matrix in `p3x-panel-live.md` remains evidence for that implementation only. It cannot certify a native replacement that has not been written.

| Shape | Caller environment | Expected | Historical actual | Exit |
| --- | --- | --- | --- | --- |
| Four trust providers, physical/logical paths and repeat | Isolated HOME, inherited real TMUX/TMUX_PANE | Trust and isolation artifacts; repeat stable | Passed | 0 |
| Invalid temp marker, scratch symlink, relative path | Same | Refuse | Passed | 1 |
| Missing/unknown trust argv | Same | Usage refusal | Passed | 2 |
| Eight dispatch phases missing options | Plain private pane | Argument refusal | Passed | 2 |
| Dispatch help | Same | Usage help | Passed | 0 |
| Prepare, native wait, collect, retain | Isolated HOME and explicit bound authority; selected protocol checkout | Candidate receipts without admission | Passed with interpreter dependency | 0 |
| Early ownership and preservation-based cleanup | Own private windows/processes | Scoped custody and retirement | Passed | 0 |
| Pre-window launch failure | Controlled staged tai fixture | No Start; retained/recovered authority | Passed using old wrapper | 1 |
| Real Codex launch, Start, reads, final, collect, cleanup | Plain pane; old launcher sets seat env; sender sets documented CODEX_SEND_SESSION | One Start; bound evidence; owned cleanup | Passed using old wrapper | 0 |
| Provider trust/temp retirement | Isolated provider configs and own temp | Exact retirement; bad marker refuses | Passed | 0 / 1 |
| Qualified owner verification and floor sources | Explicit protocol/project/path/hash options | Owner accepts | Passed via interpreter bridge | 0 |
| Stale/wrong-session/self-activation/shared-inode/projection controls | Same | Owner refuses | Passed via interpreter bridge | 1 |
| Agy automatic admission | Same | Refuse; retain available | Passed | 1 |

Previous results at the cap: 51 default Rust tests passed in 1.52 s; six explicit pane cases passed in 101.55 s with 59 CLI rows, including the real interactive Codex cycle; 69 native-envelope controls and 15 owner-consumer controls passed. Previous fmt/clippy/diff checks passed. The owner controls still used the forbidden bridge. **None of these checks was re-run in this response.** No new fast tests or real-artifact validator fixtures were added.

## Delta, gaps and decision

The unchanged branch at `45a92f7`, relative to `a8ee75c`, contains 5,286 added / 203 removed lines across 21 files. This response adds only this divergence report and corrects the withdrawn historical report. Runtime/test lines added: **0**; runtime/test lines removed: **0**. The external completion summary records the report commit and final full-branch counts.

Remaining gaps: native protocol validation with exact source citations and per-check real-artifact tests; native seat launch and environment with cited tai parity; removal of inline-code/data indirection; replacement-specific fast and plain-pane verification; the independent #p4x agy-send-to registration dependency. No protocol-source implementation or live caller was modified. Nothing was deployed and no live window was created, closed or signaled for this response.

Decision: **NO-GO / Divergence at 10 of 10.** The requested fix remains unfinished. The binding task brief requires stopping rather than exceeding the cap. Continuing the Rust implementation requires a revised round budget from Angel/Claude.
