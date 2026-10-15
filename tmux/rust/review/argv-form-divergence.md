# #argv: launch forms corrected; literal conditional ban unresolved

**NO-GO against the complete literal brief.** All five audited tmux program-launch sites use explicit multi-argument form, and the signed private harness cleans up with direct `kill-server` only after verifying its owned socket/server. All requested gates pass. Production relay/model/newchat still use format-only `if-shell -F` guards. The requested unconditional ban on that command remains unresolved: removing these guards would change the existing atomic input checks, contrary to the brief's behavior-parity requirement. No exception or redesign was assumed.

Authority: `~/desk/tmp/relay/argv-fix-brief.md`, cap three rounds. Worktree `~/desk/lab/tmux-to-rust-argv`, branch `fix-argv-form`, base `0170defc2b4fd7e4440764f889e6cb3bd2e34e66`. Evidence: `~/desk/tmp/relay/port/argv-evidence/`. Final commit and added/removed counts are recorded in `~/desk/tmp/relay/port/argv-summary.md` after commit.

## What changed

| Launch site | Before | After |
| --- | --- | --- |
| Private server hold | One `/bin/sleep 120` command string | `new-session ... -- /bin/sleep 120`, with program and duration as distinct arguments |
| Private Rust fixtures | One `exec /usr/bin/env ... <test-exe> ...` command string | tmux `-e` environment entries, `--`, test executable and each test argument separately |
| Owned pane custody test | No explicit program, implicitly starting the default shell | Explicit `-- /bin/sleep 120` native holder; same owned custody/cleanup purpose |
| Panel bootstrap | Already separate native program/arguments | Explicit `--` before the existing Rust bootstrap argv |
| Model example split | Already separate native program/arguments | Explicit `--` before the existing Rust example executable and `hold` argument |

The sleep holder follows the original private harness's program/duration at base `tests/support/private_server.rs:101`; no new external program constructor was added. The fixture keeps its original two environment values and original executable/test arguments. Its pane PID is now checked through the native process-image API against the actual Rust test executable, and the private gate logs retain those PID/image observations.

Private cleanup no longer uses a tmux conditional command. It reads the signed lease, verifies the socket peer's PID/generation/device/inode, checks tmux's PID/start-time/nonce/socket-path output, re-attests the same signed record, and then issues `/opt/homebrew/bin/tmux -N -S <owned socket> kill-server`. Retirement observations and socket identity checks remain. The default server is never a cleanup target.

The new fast Rust AST check traverses `src`, `tests` and `examples`, resolves the current argv-vector construction, requires an explicit separator and at least two program-argv elements, and rejects the original direct/built command-string cases. It also rejects `run-shell` and shell-executing `if-shell` forms, including formatted strings. Format-only `-F` guards are deliberately retained pending the requested clarification. This is **not** the unconditional `if-shell` rejection requested in item 3. The scanner is a regression check for these source construction forms, not a formal verifier of arbitrary Rust data flow. Its parser is a dev dependency already present in the lockfile; no runtime dependency or interpreter driver was added.

## Why the remaining guard removal was not performed

The installed pinned tmux 3.7c manual states that multiple launch arguments execute directly without a shell (`tmux.1:978-1005`). It separately states that `if-shell -F` does **not** execute its condition, but evaluates its expanded format as empty/zero versus success (`tmux.1:7850-7872`). Excerpts are retained in `r1/tmux-argv-man.txt` and `r1/tmux-format-mode-man.txt`.

The existing guards are used at actual effect boundaries:

- `src/runtime.rs:981,1121,1129,1216`: identity/geometry checks, focus/activity checks, Enter, and removal of exact own staged bytes.
- `src/model.rs:432` and `src/new_chat.rs:451`: native screen/identity checks immediately around model/newchat input.
- `src/model_payload.rs:67`: the compatible nested format-guard command grammar, also checked by `identity.rs:457` and its tests.

These guards enqueue native tmux operations; they do not use the condition as an OS shell program. A separate observation followed by unguarded input would lose their atomic protection. Aliasing the forbidden command would only conceal its use and was not attempted. A clarification was requested while independent launch and harness work continued. No answer was received before the three-round stop. Accordingly, the report remains NO-GO rather than claiming the literal blanket ban is fulfilled.

## Gates on the final source

Toolchain: existing Rust 1.99.0 via its explicit toolchain-bin PATH; SDKROOT `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`. Cargo operations used `--locked --offline`. No toolchain or installed binary was changed.

| Gate | Result | Test body time |
| --- | --- | --- |
| `cargo fmt -- --check` | PASS | — |
| Strict all-target Clippy, warnings denied | PASS | 0.59 s command |
| Default library tests | 157 passed, 14 explicit workers/gates ignored | 2.94 s |
| New argv source/regression tests | 2 passed | 0.21 s |
| `runtime::tests::private_delivery` | PASS | 6.94 s outer supervisor |
| `runtime::tests::effect_faults` | PASS | 2.69 s |
| `runtime::tests::activity_gate` | PASS | 1.15 s |
| `runtime::tests::activity_elsewhere_then_quiet` | PASS | 0.90 s |
| `test_server::lease_rejections` | PASS | 0.06 s |
| Additional `test_server::retirement_observations` | PASS, 16 distinct owned private servers | 0.74 s |

Thus the default suite has **159 passing tests**, plus the five required signed private gates and the additional retirement probe. Six explicit `panel_plain` real-pane harnesses remain ignored; none was run for this slice. The private gates ran serially, with native fixture image checks and direct leased-server retirement. `r3/cargo-test.txt`, `r3/fmt.txt` and `r2/final/*.txt` retain full logs. Earlier passes were repeated after adding the native image assertions; no failed or flaky gate was relabeled as a pass.

| Real-tab proof row | Caller/env | Exit / delivered | Scope |
| --- | --- | --- | --- |
| Real/default tmux testing | None | Not run | No real test tab or real-seat test traffic was created; the shared lock was held by another lane |
| Signed private harness | Native Rust supervisor; fresh signed `KS01_RUN_CAP`; explicit owned `-S` socket | Six explicit tests exit 0 | Supporting private proof, not a complete production state matrix |

## Whole-crate grep

Exact command: `git grep -n -i -E 'python|perl|fish|bash|/bin/sh|ruby|node|zsh|sh -c|run-shell|if-shell' -- tmux/rust ':!*.md'`. It returns **102 matching lines**, exit 0; raw output is `r3/required-grep.txt`. Every match is accounted for:

| Lines | Explanation |
| --- | --- |
| 47 | JSON-schema `node` identifiers and messages |
| 21 | Filesystem inode field/variable/test names |
| 10 | Existing format-only conditional guards, delivery grammar and expected guard tests; these are the unresolved literal-ban finding |
| 10 | Claude tool name `Bash` in tool allowlists, native decoding and preserved screen fixtures |
| 7 | AST checker command recognizers and negative parser fixtures, never executed as tmux commands |
| 4 | Installed CLI package paths/identity regex and a preserved `!node_modules` exclude glob |
| 2 | English words in a preserved generated-answer screen fixture |
| 1 | Recognition of an existing Node-backed CLI process name, not a process launch |

No new interpreter launch was introduced. The pre-existing public panel-helper selection can still resolve to relay-stable interpreters, and legacy model payload compatibility can emit quoted command data for its old caller. Those inherited findings are not corrected by this argv-only patch and no full-runtime interpreter-free claim is made.

## Every Command::new

All 34 sites are inherited constructors; raw final-source inventory is `r3/commands.txt`.

| Location | Concrete program / selection |
| --- | --- |
| `src/panel_dispatch.rs:515`, `src/new_chat.rs:449`, `src/identity.rs:721` | `/opt/homebrew/bin/tmux` → `/opt/homebrew/Cellar/tmux/3.7c/bin/tmux` |
| `src/model.rs:119` | Canonical pinned tmux executable from the validated model context |
| `src/identity.rs:411` | Same pinned tmux image held by the authenticated namespace |
| `src/panel_dispatch.rs:577` | `/bin/ps`; live old dispatcher line 256 |
| `src/panel_dispatch.rs:711` | PATH `cc-msg`, `codex-send-to`, or `agy-send-to`; old dispatcher lines 340-350; currently public relay-stable links, unchanged |
| `src/panel_cleanup.rs:408` | PATH `trash`, resolved `/usr/bin/trash`; live old dispatcher line 933 |
| `src/panel_launch.rs:265` | Resolved `codex`, `claude`, `agy`, or the existing pinned DeepSeek-compatible Claude path; old `tai.fish:164-236`; unchanged selection/profile |
| `src/runtime.rs:236` | Current native Rust runtime, relay producer re-exec |
| `tests/panel_plain.rs:85` | `panel-seat-trust` or `panel-dispatch` private alias to the copied candidate |
| `tests/panel_plain.rs:206,479,496,509,533,613,627,632` | Pinned tmux, own pane inspection/launch/cleanup only |
| `tests/support/panel_protocol.rs:978` | Fresh copied candidate under its panel-dispatch alias |
| `tests/support/private_server.rs:41` | Current Rust test executable, signed supervisor child |
| `tests/support/private_server.rs:89,131,207,241` | Pinned tmux, exclusively the freshly leased private socket; fixture launch and direct cleanup corrected here |
| `tests/support/runtime.rs:102` | `/bin/cat`, existing owned EOF/cleanup fixture at the base |
| `tests/support/runtime.rs:183,499`, `tests/support/identity.rs:112,154` | Current Rust test executable, existing owned workers |
| `tests/support/runtime.rs:808` | Pinned tmux attached client on the signed private fixture |
| `examples/model_lab.rs:9` | Pinned tmux |
| `examples/model_lab.rs:31` | `codex-model` selected through the example's private candidate PATH |
| `examples/model_lab.rs:98` | Explicit operator-supplied actor argv, intended native Codex or the compiled Rust example actor; no example actor was launched in this slice |

## Three-round stop

R1 inventoried the complete crate and corrected the launch/private-cleanup forms. R2 added the AST and native-image checks and ran the full signed private gates. R3 audited final fmt/tests/Clippy, grep, process inventory and evidence, committed this bounded result, and prepared the one final `#argv` handoff to `config-tt:codex-lead`.

No production input guard, public link, relay-stable implementation, main config, caller, memory, other worktree or foreign window/process was changed. No subagents, code comments, headless Claude, real-server kill or deployment was used. The unresolved unconditional conditional-command ban and broader inherited readiness gaps remain explicit. **NO-GO for completion of the literal brief; the argv/leased-cleanup correction is reviewable separately.**
