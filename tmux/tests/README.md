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

`tai seat` supplies seat/scratch as TMPDIR. Claude seats also use a validated short `/private/tmp/panel-<seat-inode>` alias to that scratch and a native environment file; remove that exact alias with the owned seat at round cleanup. Astra defaults explicitly to gpt-6-sol low; use `-m` for another model, not `-c model=...`.

Agy's native `--sandbox` blocked the outside read but allowed the outside write in the installed 1.3.3 probe. Its existing unattended approval bypass remains, with a loud isolation-limit warning. It is not advertised as fully confined. Native filesystem policies also do not forbid harmless in-seat command chaining or every outside `cd` metadata operation.
