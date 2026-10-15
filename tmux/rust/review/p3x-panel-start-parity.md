# #p3x G1-G3: prompt parity and two qualifying native cycles

**PASS for the authorized G1-G3 slice.** Start, task/input bytes and read-receipt instructions already match the live old dispatcher. No runtime or fixture change was warranted. Two fresh Codex cycles passed the unchanged collector and owned cleanup in 11.62 and 10.47 seconds. This report does not authorize integration deployment or resolve the earlier validator limitations.

Authority: `~/desk/tmp/relay/port/panel-g.md`, hard cap G3. Worktree: `~/desk/lab/tmux-to-rust-integrate`, branch `integrate`, base `1a03e7e99a77f48d5969b208803afa4e4086bc8c`. Only this report is committed. Evidence root: `~/desk/tmp/relay/port/panel-evidence/G1-G3/`.

## Byte comparison and instruction inventory

G1 snapshots the actual live old sources, without executing their interpreter entry points: `~/.config/tmux/tools/panel-dispatch`, `~/.config/tmux/tools/panel-seat-trust`, and `~/.config/fish/internal/tmux/tai.fish`. Matching Rust source snapshots and hashes are alongside them in `G1/`. A final comparison confirmed that the live source files remained unchanged during the slice.

| Seat-facing content | Live old behavior | Rust behavior | Byte evidence |
| --- | --- | --- | --- |
| Start, all transports | `panel-dispatch:24,340-364`: one constant, sent through the role helper | `src/panel_dispatch.rs:10,703-769`: the same constant and role-helper delivery | 65 identical bytes, SHA256 `d9c9dc3a2c8c9ed7d100585612e692a4602235330435261b52c0906337433d1b` |
| `PROMPT.md`, including full-read receipt instructions | `panel-dispatch:301-302`: copy `packet.prompt` bytes; no generated or appended task prose | `src/panel_dispatch.rs:436-440`: copy the same packet bytes | 607 identical bytes in both fresh native results, SHA256 `24675683296d26412eb67bcc65bd9d2abc3aebfc663cf8f33b38ff9be2137a3e` |
| `intake.md` | Same copy loop, `packet.delivered_input` | Same copy loop and packet field | 25 identical bytes, SHA256 `076e4fdd343e6b1c9e19ba0c561c8f595213131cf17ff0721f40eee6be9aa387` |
| Clean Codex home configuration | `panel-seat-trust:20-46`: seed the fixed configuration; append exact-seat trust entries | `src/panel_trust.rs:10-36,323-342`: the same configuration and trust-entry form | 579 identical base bytes, SHA256 `6e21bf5aec1e28123859184ffb92fdf3445aa3ede96cd961f1885980371b7f96` |
| Ambient instruction files | `panel-dispatch:26,281-288` and trust helper: reject ancestor instruction/context files and panel-home `AGENTS.md` | `src/panel_dispatch.rs:369-403` and `src/panel_trust.rs:269-273`: same exclusions | No dispatcher-added instruction file or extra user message; each native transcript contains exactly one Start |
| CLI settings and environment | `tai.fish:164-236`: requested model/effort, fixed tool/policy flags, clean Codex home, per-seat scratch/provider settings | `src/panel_launch.rs:35-144`: equivalent profiles; `src/panel_trust.rs:350-409`: provider sandbox settings | No system/append-system prompt, extra task argument, memory text or read-receipt prose in either launcher |

The old dispatcher does not author a task prompt or a separate read-receipt instruction. It accepts the caller's prompt as an immutable packet input. Consequently, `old-expected-PROMPT.md` and `old-expected-intake.md` in the comparison artifacts mean the exact request bytes the old source copies, not a claimed old-tool execution. The Rust comparison files were independently recovered from successful native tool results and compared with those request bytes and prepared input hashes. No old real cycle was run in this slice.

The live wrapper chain was inspected too. `_agent_limit` resolves an external executable before its no-config exec, so Astra/Fable do not enter the interactive `codex`/`claude` functions or acquire their extra wrapper flags/warnings. Agy forwards its args through the same limit wrapper. Confined DeepSeek sets provider/model environment and executes the pinned CLI with the supplied seat flags; it adds no natural-language prompt. Snapshots of all five relevant wrapper sources are retained in `G1/`. No transport supplies another task or read-receipt instruction.

The complete pilot task, unchanged from F12 and both failed integration attempts, is:

```text
Operator-authorized native dispatcher pilot. Preliminary prompt reads do not disqualify this pilot. Now read PROMPT.md and intake.md fully with two exec calls using these exact bodies: const r = await tools.exec_command({cmd:"cat PROMPT.md"}); text(r); and const r = await tools.exec_command({cmd:"cat intake.md"}); text(r); These authorized cat reads are not test execution; after these full-result reads, do not repeat them. No reads outside this seat, no test execution and no peer messages. Reply exactly with two lines:
Grounded check: owned input contains alpha beta; no tests executed.
Verdict: PASS
```

Actual text diff:

```text
Start:        diff -u G1/old-start.txt G1/rust-start.txt              -> empty, exit 0
Codex config: diff -u G1/old-codex-config.toml G1/rust-codex-config.toml -> empty, exit 0
PROMPT.md:    diff -u old-expected-PROMPT.md rust-native-PROMPT.md    -> empty, exit 0, both cycles
intake.md:    diff -u old-expected-intake.md rust-native-intake.md    -> empty, exit 0, both cycles
```

The empty diff files are retained in `G1/` and `G2/<cycle-nonce>/`. No content normalization was applied to these byte comparisons. Different fresh seat paths and the actual caller's relay label are identity fields, not changed instructions. Non-instruction serialization is not claimed byte-identical: the old Codex argv spells effort as `model_reasoning_effort="low"`, while Rust spells it `model_reasoning_effort=low`; both native turn contexts report `gpt-6-sol`, effort `low`. Provider JSON spacing/key order also differs between serializers. None adds task or read-receipt instructions; no such formatting was changed here.

## Prior refusals and fresh real evidence

Inspection of the preserved integration transcripts found more than an unexplained choice of `rg`. Both seats attempted the instructed `cat` bodies, received exit 127 with `zsh:1: operation not permitted: cat`, and then read with `rg`. The unchanged collector refused the resulting receipts. G1 retains the relevant native tool call/results. This is evidence of executable permission refusals in those attempts, not proof of a prompt omission or a proven cause of the later successful executions. Both old and Rust launch sources specify the same Codex filesystem policy; an old real failure was not observed here.

G2 ran the existing release test `native_interactive_start_collect_cleanup` exactly twice, serially, from the fresh owned plain zsh caller `config-tt:p3x-test-g`, @397/%437. Real inherited TMUX was `/private/tmp/tmux-501/default,1793,3`; only the documented `CODEX_SEND_SESSION=config-tt` routing prefix was supplied. The runner script, full caller PATH, command resolution, exact candidate hashes and both exit codes are retained in `G2/`.

The unchanged candidate SHA256 is `27a895f8b1677016ae854a69a083b661bbe63d5b17993d9184db203339561b42`, matching the integrated release binary, the earlier integration candidate, and each freshly staged panel copy. The existing release harness SHA256 is `df2a0b0b575f49dff265f1b1a7e61fadb7e2d3ad709d9e594786f4277401fb8f`; its build dependency record binds the candidate to this integrate worktree. No code was rebuilt or changed for these runs.

As required by the standing public-helper rail, Start used the installed public `~/.local/bin/codex-send-to`, resolving to the native relay installed at `~/.local/share/angelstar/74f7a4e147317e4fa787dcef4b3c4b47d0580182/angelstar-runtime`, SHA256 `bd11f6218b66a920aef102c8ce6ede5535950e6aa2a8cdbc22dc4118b47cb8cf`. Public links and bytes were checked before/after and not changed. These runs did not inject the private integration sender shim used by the earlier integration tests; they therefore certify the panel gate using the actual public relay, not a new private integrated-relay gate.

| Evidence | Cycle 1 | Cycle 2 |
| --- | --- | --- |
| Fresh root under `panel-evidence/corrected/` | `plain-1792093816247575000` | `plain-1792093827870809000` |
| Native seat | @398/%438, PID 21571 | @399/%439, PID 22401 |
| Native session | `01a1411d-8c09-7ef2-bf84-936a5d6e043f` | `01a1411d-b92c-7362-8b98-296b568e99ce` |
| Exact Start / completed final count | 1 / 1 | 1 / 1 |
| Complete prompt call/result lines | 27 / 30 | 25 / 28 |
| Complete intake call/result lines | 32 / 35 | 30 / 33 |
| Prepare / launch / wait / collect / cleanup exits | 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 |
| Phase times, milliseconds, in that order | 231 / 1721 / 9302 / 145 / 99 | 126 / 1767 / 8253 / 137 / 100 |
| Full real test | PASS, 11.62 seconds | PASS, 10.47 seconds |
| Own window/process closure, trust retirement | All true | All true |

Each root retains exact argv/stdout/stderr in `parity.json`, the delivered Start reference in `interactive-batch/a-start.json`, full native JSONL, `a-reads.json`, `a-final.md`, `collected.json`, and `interactive-cleanup.json`. Both read receipts have `actual_reads_verified=true` and complete literal output for both files. Both final hashes are `28cd1acdb2cbf78df8ae93b0e88ae62bae33d05c6b8e64da984527485781985b`. Fresh request/seat/session/claim evidence was used for each attempt; no Start was replayed. Fixture authority/boundary controls do not certify independent production panel admission.

## G3 completion and scope

G1 compared live and Rust instructions and inspected the prior failures. G2 completed the two fresh qualifying cycles without any prompt, runtime, collector, timeout or harness edit. G3 audited the receipt bindings, retired the owned runner and committed this report. Byte comparisons and `git diff --check` pass. Runtime and fixture sources remain exactly at the base; broader fast tests were not repeated for this documentation-only result.

Only the fresh owned seats and runner were closed. `G3/windows-after.txt` records all pre-existing windows still present, including the unrelated active `p4x-l2` harness. No other worktree, primary config, public link, installed runtime, relay-stable, caller, memory or credential was changed. No subagents, headless Claude, interpreter bridge, collector relaxation or deployment was used. Prior selected-schema/normal-form limitations and other integration gates remain outside this narrow result. One completion message is sent to the exact existing interactive `config-tt:claude` pane at G3.
