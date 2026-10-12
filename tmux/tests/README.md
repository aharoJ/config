# Relay keeper tests

Run from the repository root:

```sh
tmux/tools/tmux-lab run -- python3 tmux/tests/relay-keepers.py ~/desk/lab/relay-keepers-run
tmux/tools/tmux-lab run -- python3 tmux/tests/relay-native-lab.py ~/desk/lab/relay-native-run
```

Use a fresh output directory for each run. The first suite replays 52 saved empty/draft composer captures and tests exact routing on a private tmux server, including a colon session name, missing targets, sender/code preservation, automatic waiting for a draft, and an empty busy composer. Its three terminals are inert renderers. The second suite launches actual interactive Claude Code and Codex TUIs on the private server and records their exchange, a test-owned Codex draft, and input during a reply. Neither suite runs a headless Claude process.

Normal commands remain `cc-msg`, `codex-send`, `codex-send-to`, `agy-send-to`, and `relay <session>:<window> <text>`. Session names are resolved by exact name to tmux session IDs; the address separator is the last colon. Window names are resolved live. A draft causes automatic waiting, with the message record available through `relay status [id]`. Sender/window labels and short message codes travel in both direct text and archived pointers. Messages without a code receive one.

An explicit `--clear-draft` clears the named pane, `--operator` interrupts/clears before sending, and `--keys <keys...>` performs an explicitly requested TUI action on that pane. Normal messages never clear a draft. Source ancestry and an inherited live pane name supply attribution, without source binding or launch-form gates.

`cc-msg` refuses a message to the caller's own pane unless `--allow-self` is explicit. It rejects a leading `session:window` positional rather than treating it as text; use `CC_MSG_SESSION`/`CC_MSG_WINDOW` or `relay <session>:<window> <text>` for targeting. Explicit clear/key actions remain available on the named pane.

A submitted record confirms the tmux submission, not a model acknowledgment. After possible input, an error is recorded without replaying the message. Read the record and pane to resolve it.

The composer recognizer is shared with the model/reset commands. Their picker and reset tests remain under `codex-model-*` and `codex-new-*`. The specialized picker/reset operations remain separate from ordinary relay delivery.

Published captures use synthetic account identities and directories. ANSI sequences, widths and cursor geometry are preserved; manifest digests identify the sanitized bytes. Synthetic-derived cases retain their labels.

## Panel seats

`python3 tmux/tests/panel-seat-isolation.py <fresh-evidence-dir>` checks four launch policies and the actual Codex native permission profile. `tmux/tools/tmux-lab run -- python3 tmux/tests/panel-seat-native.py <fresh-evidence-dir> [fable|deepseek|astra|gemini ...]` runs visible interactive native seat probes, watches result files, and closes only its private test server. No headless Claude process is used.

`tai seat` supplies seat/scratch as TMPDIR for Astra/Agy. Fable/DeepSeek use a real mode-0700 `/private/tmp/panel-<seat-inode>` temp directory, validated against its `.panel-seat` ownership marker, with native read/write access limited to their own seat and temp. `panel-temp.json` records the exact cleanup target: validate its marker and trash that directory with the owned seat at round cleanup. Symlinked or mismatched temp directories are refused. Astra defaults explicitly to gpt-6-sol low; use `-m` for another model, not `-c model=...`.

## Panel dispatcher development

`python3 tmux/tests/panel-dispatch-native.py` runs contrasting native-envelope controls. `python3 tmux/tests/panel-dispatch-integration.py` exercises the actual protocol-owned consumers using their fixture builder; `PANEL_PROTOCOL_ROOT` selects an explicit protocol checkout. Synthetic qualified controls do not activate production checks.

`tmux/tools/tmux-lab run -- python3 tmux/tests/panel-dispatch-live.py /absolute/new/output fable` launches one owned interactive seat through tai and the sanctioned relay, collects native read/final/model evidence and tests owned cleanup. Other tested transports are `deepseek` and `astra`. These pilots use clearly labeled control proofs, not independently authorized production admission. Failed controls remain evidence. No headless Claude or existing windows are used.

`panel-dispatch` has exclusive-creation, explicit-hash `prepare`, `launch`, `wait`, `collect`, `retain`, `verify` and `cleanup` phases. Only independently bound canonical dispatch/ledger authority reaches the protocol consumers. Source labels, delivery and decoder success alone do not supply admission, quorum or terminal authority. V1 requires independent first-attempt authority and a zero automatic-redispatch budget. It atomically seals one initial-launch claim per project/topic/cycle/round in `~/.local/state/panel-dispatch/initial-launches/` before spawning anything. A failed launch does not release that claim; cross-batch/manual replacement and FAIL retries are unsupported and refuse. Do not clear a claim to force a retry. This conservative transport guard confers no supersession or vote authority and is not a publication-recovery guarantee.

Add `prestart-failure` after the transport in the live test command to test a real partial launch: the post-launch gate refuses, no Start is called, explicit non-observation retention is produced, and owned cleanup closes the pane/process/temp/trust state. Cleanup refuses wrong receipt phases, source/context/batch/attempt chains, missing preservation, or missing explicit non-observation causes before touching any target. Agy is hard-refused by `collect`; only unadmitted retention/manual treatment is available.

`sendkeys-failure`, `capture-failure`, and `identity-failure` test earlier owned recovery boundaries. The dispatcher seals spawn intent and kernel-bound prestart ownership before tai may type its CLI boot command, then automatically retains explicit non-observation and cleans owned prestart targets on later launch-stage failure. Once Start delivery might have begun, it never uses this non-observation recovery path. Persistent inability to establish kernel custody remains fail-closed with sealed spawn pointers; it does not permit an unverified kill or clearing the initial-attempt claim.

Unsupported envelopes and absence-based action contradictions are unqualified. Agy launches retain their accepted write-isolation warning, but the available Agy envelope lacks proven effective model/session/action linkage for automatic admission; retain it unadmitted rather than invent identity. Cleanup preflights every target/temp, preserves immutable native evidence, checks kernel identities for observed pane descendants and retires only owned trust/temp entries. It does not promise universal OS containment or publication recovery.

Agy's native `--sandbox` blocked the outside read but allowed the outside write in the installed 1.3.3 probe. Its existing unattended approval bypass remains, with a loud isolation-limit warning. It is not advertised as fully confined. Native filesystem policies also do not forbid harmless in-seat command chaining or every outside `cd` metadata operation.
