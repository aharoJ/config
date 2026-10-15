# #p3x panel lane: NO-GO

Branch `port-panel`, base `a8ee75c`. This is a partial implementation and a divergence report, not a completed panel cutover. Do not deploy it as a replacement for the active panel tools.

The baseline `panel-seat-trust` is ported into the multicall binary in `src/panel_trust.rs`. Its repository launcher is a relative symlink to the adjacent staged `angelstar-runtime`, with dispatch through argv[0]. The active `panel-dispatch` is not ported. The newer active trust helper's isolation artifacts are not ported either.

## Source and caller inventory

The assigned worktree contains a 203-line `tmux/tools/panel-seat-trust`, but contains neither `panel-dispatch` nor any of the five panel test files. The active config checkout contains the 1,003-line dispatcher, a newer 234-line trust helper, and the panel tests. Those sources were inspected read-only; they were not substituted into the worktree or executed.

Searches covered `~/.claude`, `~/.codex/AGENTS.md`, `~/.skills`, `~/.config/fish`, `~/.config/tmux`, the skhd locations, and the worktree. The retained file inventory is `~/desk/tmp/relay/port/panel-caller-files.txt`. Historical intake copies and transcript caches mention the tools but are not additional invocation contracts. Direct callers and the test README extracts are in `panel-evidence/direct-callers.txt` beside this report's external summary.

The actual trust caller is `~/.config/fish/internal/tmux/tai.fish:216`: `panel-seat-trust <claude|deepseek|codex|agy> <physical-seat-directory>`, inheriting HOME and ordinary pane environment. The trust helper never infers routing from TMUX or TMUX_PANE. An explicit `tai --session` remains a launcher concern.

The dispatch CLI has `prepare --request --batch --sha256`, `launch --prepared --sha256`, `own --prepared --seat-id --pane --sha256`, `wait --launched --locations --locations-sha256 --output --sha256`, `collect --launched --native-index --native-sha256 --sha256`, `retain --launched --native-index --native-sha256 --output --sha256`, `verify --protocol-root --project-root --dispatch --ledger --ledger-sha256 --output --sha256`, and `cleanup --launched --collected --collected-sha256 --output --sha256`. Its own launch function invokes `own`. The active tests exercise these phases and import their implementation functions. The README also documents the `tmux-lab run` live pilot. The dispatch harness inherits HOME/TMUX context and optionally lab socket variables; it explicitly sets recipient routing for sanctioned relay Start delivery.

Source snapshots and SHA256s are retained under `~/desk/tmp/relay/port/panel-evidence/sources/`:

| Source | SHA256 |
| --- | --- |
| Baseline trust | `0d49ff8cf97b51247e3f85c7e403dd6b440cb4a130a305fb874738991c4fa169` |
| Active trust | `ba79df3b7be53cf0783750cf64619a371b88d40468e212b8bf9381c06d6f10fc` |
| Active dispatcher | `8367914bbdc6e08ac0f8925eead26a09b3f4716781e3aa1e37734ebeaf30a725` |
| Active tai | `e5e2cfdabd62f4b3cac879deeb0fb7500d11438299f06f985a2a3952b969962c` |

## Implemented baseline behavior

The Rust helper preserves exact seat-name matching, physical/logical path aliases, owner/private-mode validation, provider trust records, DeepSeek key-tail approval and rejection removal, clean Codex home seeding, exact auth symlink checks, required boolean config settings, conflicting trust refusal, five-second directory locks, exclusive temporary creation, fsync and atomic replacement. Existing config data and modes survive; already trusted configs are not rewritten. DeepSeek retains the old partial-mutation order: folder trust can be committed before a short-key refusal.

Lock release uses native removal of the owned empty lock directory, replacing the old external `trash` call. JSON formatting and parse/OS-error diagnostics are native, so byte-for-byte JSON formatting and interpreter tracebacks are not preserved. All exercised semantic outputs and exit codes match the baseline source contract. Expected results were derived from source; the old executable was not run as an oracle.

## Parity matrix

The installed candidate was copied to `~/desk/tmp/relay/port/panel-evidence/installed-candidate/angelstar-runtime` and invoked by name through private PATH symlinks. Its SHA256 is `00be498f675dc8d937f17bad221b246c825079c08760089dcac4bdacd6fbf168`. It is a debug candidate built with the pinned lockfile, not a deployed public binary.

All rows ran from an initially plain Fish pane in the lane's private `config-tt:p3x-test-trust` window. The final run used pane `%329`, window `@300`; a prior run used `%327`, window `@298`. The runner inherited `TMUX=/private/tmp/tmux-501/default,1793,3` and the actual `TMUX_PANE`. No CC_MSG, CODEX_SEND, or AGY_SEND routing variables were set. Each provider ran with a fixture HOME under `~/desk/tmp/relay/port/panel-evidence/`; the PATH shim selected the copied native binary. The existing valid physical seat was read only; no seat or temp folder was created outside ~/desk. The fixture homes and PATH shims were removed after success. Both private windows exited with their sole test process and are gone.

`panel-evidence/plain-parity.json` contains each exact argv, caller environment, expected/actual exit, stdout, stderr and elapsed time. The successful provider rows also assert both alias records, preserved unrelated values, auth-link identity and idempotent file bytes/inodes.

| Shape | Expected | Actual | Expected/actual exit |
| --- | --- | --- | --- |
| `claude <physical-seat>` | Trust both aliases, preserve unrelated config | Matches | 0/0 |
| `deepseek <physical-seat>` | Trust both aliases and approve key tail | Matches | 0/0 |
| `codex <physical-seat>` | Seed clean home and trust both aliases | Matches | 0/0 |
| `agy <physical-seat>` | Add both trusted workspaces | Matches | 0/0 |
| Each of four kinds with `/tmp` alias, second call | Physical-path announcement, no config rewrite | Matches, four rows | 0/0 |
| Empty argv | Usage refusal | Matches | 2/2 |
| `--help` | Baseline usage refusal | Matches | 2/2 |
| Unknown kind | Usage refusal | Matches | 2/2 |
| Missing seat | Usage refusal | Matches | 2/2 |
| Extra argv | Usage refusal | Matches | 2/2 |
| Relative seat | Refuse before trust | Matches | 1/1 |
| Unrelated directory | Refuse before trust | Matches | 1/1 |
| Absent seat | Refuse before trust | Matches exit; native diagnostic | 1/1 |
| Malformed config | Refuse without replacing bytes; release lock | Matches exit; native diagnostic | 1/1 |
| Short DeepSeek key | Refuse after committing folder trust | Matches | 1/1 |
| Existing lock | Refuse after five seconds, preserve foreign lock | Matches, 5,012 ms | 1/1 |
| Codex seed before refusal controls | Establish clean fixture panel home | Matches | 0/0 |
| Codex global instructions present | Refuse | Matches | 1/1 |
| Codex real auth file | Refuse without replacing it | Matches | 1/1 |
| Codex wrong auth symlink | Refuse | Matches | 1/1 |
| `panel-dispatch --help` | Dispatch help | Unknown native entry point | 0/1, divergence |
| Each dispatch phase without required options | Phase argument refusal | Unknown native entry point, eight rows | 2/1, divergence |
| Current tai trust invocation with isolation expectations | Scratch/settings/temp/environment artifacts plus trust | Baseline trust only | Cutover divergence; no live launch attempted |

There are 23 passing baseline trust invocations and nine explicitly recorded dispatcher divergences. A full success-path dispatcher matrix does not exist for this candidate.

## Tests and grep

`cargo test --manifest-path tmux/rust/Cargo.toml`: 43 passed, 0 failed; 12 existing unit harness cases and one explicit plain-pane integration case ignored in the default suite. Unit test execution was 1.04 s. Fourteen new unit tests cover the baseline helper's grammar, provider mutations, idempotence, file modes, auth-link refusals, strict Codex settings, invalid config, atomic collision and lock serialization. The ignored integration case was run explicitly from the two private windows above; the final invocation completed and wrote its report.

`cargo fmt --manifest-path tmux/rust/Cargo.toml --check` and `cargo clippy --manifest-path tmux/rust/Cargo.toml --all-targets -- -D warnings` passed. `git diff --cached --check` passed. Logs are in `panel-evidence/cargo-test.txt` and `panel-evidence/clippy.txt`.

`git grep -n -i -E 'python|perl|/bin/sh|bash' -- tmux/rust/src` produced no output, exit 1. The staged new module was included in this check. New production/test Rust files contain no code comments.

The first commit attempt was rejected by the existing private-capture scanner because synthetic grammar-test paths resembled capture pointers. Provider fixtures now use explicit `/fixtures/` identifiers, and grammar cases generate names from synthetic suffixes. Tests and clippy passed again. The hook and its allowlist were not changed or bypassed.

There are no old panel tests to delete in this base. The active config checkout's panel tests were left untouched, as required by the no-deploy/no-main-edit rail. Their replacement remains incomplete with the dispatcher.

## Every Command::new

The new production module contains zero `Command::new` calls and spawns no process. The complete Rust-source search is retained in `panel-evidence/commands.txt`.

| Location | Program and justification |
| --- | --- |
| `src/identity.rs:396`, inherited | The existing namespace-pinned tmux executable; verified relay operations |
| `src/identity.rs:695`, inherited | `/opt/homebrew/bin/tmux`; default-socket server attestation |
| `src/runtime.rs:233`, inherited | The current Rust executable; owned relay delivery producer |
| `tests/panel_plain.rs:23`, new | `panel-seat-trust` PATH shim to the copied candidate itself; actual multicall argv[0] smoke |
| `tests/panel_plain.rs:59`, new | `/opt/homebrew/bin/tmux`; read-only proof of the runner's own pane/window |
| `tests/panel_plain.rs:286`, new | `panel-dispatch` PATH shim to the same candidate; record absent-surface divergences |
| `tests/support/private_server.rs:41`, inherited | Current Rust test executable; signed fixture supervisor |
| `tests/support/private_server.rs:89,129,183,203`, inherited | Pinned tmux; existing private-server fixture lifecycle |
| `tests/support/identity.rs:112,154`, inherited | Current Rust test executable; account-home/process-identity controls |
| `tests/support/runtime.rs:87`, inherited | `/bin/cat`; existing owned-child cleanup control, test only |
| `tests/support/runtime.rs:167,464`, inherited | Current Rust test executable; existing runtime fixture actors |
| `tests/support/runtime.rs:773`, inherited | Pinned tmux; existing private attached-client fixture |

## Divergences that prevent GO

1. The live dispatcher depends on a caller-selected external protocol checkout. `protocol()` imports that checkout's `agentic_consumers` and `ledger_schema`; `collect()` invokes its schema validator; `verify()` invokes its context/evidence/pass-source consumers. Those checked-out implementations total 5,253 lines and include further protocol dependencies. The current contract is execution of the selected owner implementation, not just parsing JSON. There is no native owner-consumer entry point to call. Keeping those imports, invoking an interpreter, or silently substituting weaker fixed validation would violate the requested rails or parity. A native protocol consumer contract and its port are required before `verify` can preserve this authority boundary.
2. `launch()` constructs and runs Fish code that sources tai and its provider wrappers. `process_api()` also loads the legacy tmux-lab implementation. A native seat-launch/custody interface must replace these dependencies, including original early-ownership/trust-pending recovery receipts. The present work does not claim those semantics, admission, custody, collection, cleanup or initial-launch exclusion are implemented.
3. Active cleanup sends SIGTERM to remaining captured PIDs after closing the owned window (`dispatch-live.txt:925`). The rails explicitly prohibit PID signals. The permitted replacement must retain temp/trust evidence when window closure does not retire the captured descendants; that is an explicit behavior divergence, not something that can be certified as exact parity.
4. The live helper adds scratch, sandbox settings, per-seat temp ownership markers and a generated `panel-env.sh` sourced by active tai. Those changes are absent from the specified worktree source. The shell environment artifact and its consumer need a native replacement under the Rust-only rail. Shipping only the baseline trust helper into that live flow would drop isolation setup, so it is not authorized as a live cutover.
5. The baseline trust port retains semantic configuration parity rather than interpreter traceback text, JSON key order or trash history for released empty locks. Source-derived expectations are tested; there is no differential run of the removed interpreter implementation.

No public link, active config checkout, relay-stable, caller, memory, other window, session or server was modified. No CC process was started. No subagents were used. There were three local rounds: source/caller inventory; baseline implementation and fast checks; plain-pane native checks and dependency/rail divergence audit. More repetitions cannot resolve the external protocol ABI and explicit cleanup-policy conflict.

The code delta before this report is 1,072 added / 203 removed lines: 380 production-module lines, four shared dispatch/registration lines, 611 test lines, 76 manifest/lockfile lines, and one native launcher-symlink line. The full commit also adds this report; final totals are recorded in the external summary.

Decision: **NO-GO for the requested panel lane.** The baseline trust implementation is committed for review; the full tool migration remains unfinished. Resolve the native protocol-consumer and seat-launch/custody dependencies, the active trust-artifact migration, and the cleanup signal conflict before cutover.
