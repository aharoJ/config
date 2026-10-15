# #p3x live panel port: GO for merge

This supersedes `p3x-panel-divergence.md`. The source-of-truth correction from Claude authorized the existing external seat launcher and protocol APIs, clarified owned cleanup signals, and required the live helper rather than the stale worktree copy. The branch now ports both live tools into the multicall runtime. Nothing was deployed.

## Sources and callers

| Tool or dependency | Live source | SHA256 |
| --- | --- | --- |
| panel-dispatch | `~/.config/tmux/tools/panel-dispatch` | `8367914bbdc6e08ac0f8925eead26a09b3f4716781e3aa1e37734ebeaf30a725` |
| panel-seat-trust | `~/.config/tmux/tools/panel-seat-trust` | `ba79df3b7be53cf0783750cf64619a371b88d40468e212b8bf9381c06d6f10fc` |
| External tai | `~/.config/fish/internal/tmux/tai.fish` | `e5e2cfdabd62f4b3cac879deeb0fb7500d11438299f06f985a2a3952b969962c` |

The caller inventory remains at `~/desk/tmp/relay/port/panel-caller-files.txt`. Searches covered ~/.claude, ~/.codex/AGENTS.md, ~/.skills, fish, tmux, skhd and the worktree. Direct caller extracts and frozen live sources are in `~/desk/tmp/relay/port/panel-evidence/`. The live source hashes were rechecked after the port and remain unchanged.

`tai.fish:216` invokes `panel-seat-trust <kind> <physical-seat-folder>` with its inherited HOME and pane environment. Trust needs no routing variables. The implementation now includes scratch, sandbox settings, the per-seat temp marker, the environment artifact consumed by external tai, all four trust formats, and Codex home/auth/config checks.

The dispatcher CLI is documented at `~/.config/tmux/tests/README.md:32-40`. It has prepare, launch, own, wait, collect, retain, verify and cleanup phases. Every phase retains its required explicit path/hash options. Launch invokes own immediately after window creation, before entering a CLI boot command. Launch's Start delivery preserves the real source's routing prefixes (`panel-dispatch:340-352`): CC_MSG_SESSION plus CC_MSG_WINDOW for fable/deepseek, CODEX_SEND_SESSION for astra, and AGY_SEND_SESSION for gemini. These are part of the real contract, not test overrides.

Legacy tests and shared runners in the active config checkout were left unchanged. None of the panel test files exists in the assigned base. New shipped tests are Rust. Existing source tests were also used read-only as control cases, with their substantive calls redirected to the native parser/CLI.

## Implementation

The new panel modules own strict bounded JSON, stable evidence reads through held directories, exclusive immutable receipts, first-attempt exclusion claims, source and packet binding, preparation, launch ownership, prestart recovery, native transcript inspection, waiting, collection, retention, verification and preservation-before-cleanup. Existing account-home and runtime ID helpers are reused. Relay delivery calls the same binary's existing sender surfaces and retains the s9x announcement/record contract: an absolute `; record` path, delivered state, unchanged Start payload, and exact session/window/pane/PID identity. An actual interactive Codex pilot proved that path.

External tai remains external and is invoked with the same login-shell launch structure. External protocol modules remain authoritative: the bridge imports the selected checkout, checks module origin, and invokes the same schema, context, evidence and pass-source APIs. No owner validation rules were copied or replaced. The external bridge and provider protocol strings are visible in `panel_external.json`; all dispatcher and trust decisions are Rust.

Cleanup preserves the old owned-window and process-custody behavior. It validates the complete preservation chain before resolving a target, snapshots owned kernel UID/birth/unique identities, rechecks pane identity, closes only the owned window, and signals only still-matching captured survivors. No kill-server or kill-session operation was introduced. Tests exercised only their own seats and windows.

Repository tool entries are relative symlinks to the adjacent `angelstar-runtime`. Install/stage the binary in the existing `tmux/tools` layout with the bound external `fish/internal/tmux/tai.fish`, as the old adapter derives that repository layout from its source. The source digest now binds the native executable; trust helper digests follow its native alias. Old text-script authorities must not be reused with a new executable digest.

## Parity matrix and actual environment

All native CLI rows used a copied installed candidate and PATH aliases, from initially plain panes in private windows `config-tt:p3x-test-native` (`@320`, `%357`) and `config-tt:p3x-test-consumers` (`@323`, `%360`). TMUX and TMUX_PANE were inherited from those actual panes. HOME was isolated under the evidence directory. No invented routing prefix was injected. Launch itself supplied the documented prefix above.

The final native runs contain 58 CLI invocations, each with exact argv, expected/actual exit, stdout, stderr and elapsed time in its `parity.json`. The controls use clearly labeled synthetic authority proofs; they do not activate a real project panel or certify independence/admission.

The final debug candidate SHA256 is `67c1111461c325da088da34b54aa787139796b680e73b842ea705db17fc6bc55`, identical in the build output, final interactive pilot and provider-retirement candidate copies.

| Shape | Caller environment | Expected | Actual | Exit |
| --- | --- | --- | --- | --- |
| Four trust kinds, physical path | tai-style inherited HOME/TMUX | Correct trust plus live isolation artifacts | Matches, four rows | 0 |
| Four trust kinds, logical alias, repeated | Same | Physical announcement; no trust-config rewrite | Matches, four rows | 0 |
| Existing temp marker for another seat | Same | Refuse before trust | Matches | 1 |
| Scratch symlink | Same | Refuse | Matches | 1 |
| Empty/help/unknown/missing trust argv | Same | Usage refusal | Matches | 2 |
| Relative trust path | Same | Refuse | Matches | 1 |
| Eight dispatcher phases missing options | Plain inherited pane environment | Argument refusal | Matches, eight rows | 2 |
| Dispatcher help | Same | Help | Matches | 0 |
| Prepare with bound packet/source/first-attempt proofs | Same, selected protocol checkout in request | Frozen prepared receipt and private fresh seat | Matches | 0 |
| Wait on completed native transcript | Same | Candidate observation, no vote | Matches | 0 |
| Wait on absent transcript | Same, one-second request deadline | Exhausted non-response; zero redispatches | Matches | 0 |
| Collect complete reads/final with bound boundary proof | Same | Schema-checked candidate-only receipts | Matches | 0 |
| Retain native bytes | Same | Preserve findings, no vote/floor credit | Matches | 0 |
| Retain explicit non-observation | Same | Typed unadmitted retention | Matches | 0 |
| Own a newly created plain pane | Actual owned pane ID from pinned tmux | Early spawn receipt and kernel custody | Matches | 0 |
| Cleanup owned pane after retention | Same | Preserved chain, own window/process closure, trust retirement | Matches | 0 |
| Launch with external pre-window failure | Same, controlled copy of tai injects failure | Trust-pending retained; automatic no-pane recovery; no Start | Matches | 1 |
| Actual interactive astra launch | Plain pane; launcher sets CODEX_HOME/TMPDIR; Start sets CODEX_SEND_SESSION | One fresh CLI seat and one sanctioned Start | Matches | 0 |
| Actual native wait/collect/cleanup after Start | Same | Bound prompt/intake reads, final, preserved receipts, owned cleanup | Matches | 0 |
| fable/deepseek temp retirement without launching a model | Same | Validate marker, trash own temp, retire JSON trust | Matches | 0 |
| fable cleanup with changed marker | Same | Refuse before cleanup-started or target mutation | Matches | 1 |
| gemini trust retirement | Same | Retire only both owned workspace aliases | Matches | 0 |
| Verify record-only / qualified owner fixtures | Explicit protocol/project/path/hash CLI options | Actual owner consumer PASS and correct floor sources | Matches | 0 |
| Verify stale bytes, wrong session, self-activation, shared inode, projection failure | Same | Owner refusal | Matches | 1 |
| Agy automatic collection | Same | Refuse admission; retention remains available | Matches | 1 |

The final interactive run used `plain-1792086433254024000`; custody `plain-1792086465257041000`; pre-window recovery `plain-1792086471838504000`; general CLI cases `plain-1792086478206321000`; provider retirement `plain-1792086717863072000`, `plain-1792086724052329000` and `plain-1792086729869953000`. All are under `~/desk/tmp/relay/port/panel-evidence/corrected/`. An earlier separate interactive pilot also passed. Each interactive pilot used a fresh fixture project and first-attempt authority; neither retried an existing claimed round.

## Validation and grep

- Default `cargo test`: 51 passed, 0 failed, 1.03 s. Thirteen unit harness cases and five explicit pane/pilot cases are ignored by default. The new fast tests include strict evidence and decoder controls, sorted claim-key compatibility including Unicode, native action ordering, and preservation-chain refusals.
- Five explicit owned-pane cases passed: four in 77.89 s, provider retirement in 17.20 s. These include the real interactive Codex Start/read/final/collection/cleanup path, all four trust helpers, wait exhaustion, retained evidence, kernel custody, pre-window recovery, and provider temp retirement.
- All 69 live native-envelope controls passed through the native parser probe (0.443 s).
- Fifteen applicable live integration controls passed through the native CLI and actual external owner consumers (39.220 s). The first adaptation attempted two additional in-process-mock cases; those harness-only failures are retained in the earlier log. Their wait/retain behavior was then tested with real native CLI proofs instead.
- `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, and `git diff --cached --check` passed.
- `git grep -n -i -E 'python|perl|/bin/sh|bash' -- tmux/rust/src` is empty, exit 1, including all staged new modules. No new Rust code comments were added. This grep does not mean external interpreter debt disappeared: the names and tiny owner-API bridge are explicitly recorded in `panel_external.json` outside src.

Logs, exact CLI rows, source snapshots and the command inventory are in `panel-evidence/corrected/`. No old test source or own interpreter implementation is shipped as an executable tool. The runtime-created environment artifact is retained because external tai consumes it.

## Every Command::new

| Location | Executable and justification |
| --- | --- |
| `panel_dispatch.rs:523` | Pinned `/opt/homebrew/bin/tmux`: existing pane observation and owned window lifecycle; documented lab socket selection is retained |
| `panel_dispatch.rs:585` | `/bin/ps`: existing descendant graph snapshot, external system program |
| `panel_dispatch.rs:719` | Current native executable: existing cc-msg/codex-send-to/agy-send-to surfaces with the real routing prefixes |
| `panel_dispatch.rs:851` | `fish -l -c`: external, not ours; run the bound tai launcher and its existing provider wrappers |
| `panel_io.rs:389` | `python3 -B -c`: external owner API adapter, not a port of the owner's validation code; calls the selected review-protocol modules |
| `panel_cleanup.rs:408` | `trash`: external, not ours; same owned-temp retirement as the source |
| `identity.rs:396,695`, inherited | Namespace-pinned tmux command and default-socket attestation |
| `runtime.rs:233`, inherited | Current native executable: owned relay producer |
| `tests/panel_plain.rs:85` | PATH aliases to the copied native candidate: actual multicall argv[0] checks |
| `tests/panel_plain.rs:212,487,504,517,541,618,632,637` | Pinned tmux: prove the runner pane, create/inspect only test-owned panes, preserve screens and close only those own windows |
| `tests/support/private_server.rs:41` and `identity.rs:112,154` | Existing Rust test executable supervisors/process controls |
| `tests/support/private_server.rs:89,129,183,203` and `runtime.rs:773` | Existing pinned-tmux fixture lifecycle |
| `tests/support/runtime.rs:87` | Existing `/bin/cat` owned-child cleanup control, test only |
| `tests/support/runtime.rs:167,464` | Existing current-executable runtime fixture actors |

The complete unabridged search is `panel-evidence/corrected/commands.txt`. The trust implementation spawns no process. Protocol imports retain the old absence of a separate validator deadline; external launch/capture commands retain their existing budgets. No unused timeout or routing override was invented.

## Known gaps and merge requirements

1. **Other project's Python debt:** review-protocol's selected validators still execute in their existing runtime, through a small transparent bridge. External tai and its provider wrappers also retain their existing implementation languages. Both are authorized exceptions in `source-of-truth.md`, not rewritten or silently weakened validators.
2. The native `agy-send-to` surface is supplied by #p4x (`tmux-to-rust-lab/.../lab_tools.rs`), not duplicated in this lane. Merge that registration before exercising gemini launch. Agy automatic admission is intentionally still refused, exactly as the source; only retention/manual treatment is supported. No Agy model was launched in this lane.
3. An actual interactive astra pilot passed. Claude/DeepSeek provider trust, sandbox artifacts, temp ownership and retirement passed; their native envelope controls passed. Their interactive model launches were not repeated. The external tai argument assembly is preserved.
4. Native JSON formatting, human-facing parse/OS diagnostics, random seat suffix length and released-empty-lock trash history can differ; configuration semantics, named refusals, exercised exits and authority bindings are preserved. The baseline lock timeout/collision/idempotence checks remain covered.
5. Stage the live bound tai source and native helper aliases in the expected tree. Do not ship stale fish files from a8ee75c or reuse authorities bound to the old script digest. No main-checkout caller edit was made here.

The earlier three rounds plus corrected rounds four through ten were used. At the cap, all checks above pass. Every own test pane/window was closed; test-created physical seats and temp folders were removed, while evidence and candidate copies remain under ~/desk. No public link, active config source, relay-stable, caller or memory was edited. No subagents or headless Claude process were used.

Decision: **GO for merging the live panel port**, with the explicitly authorized external debt and #p4x sender registration above. This is not a deployment action. The external summary records final commit IDs and actual added/removed counts for both the correction commit and the complete branch.
