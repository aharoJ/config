# Relay keeper tests

Run from the repository root:

```sh
tmux/tools/tmux-lab run -- python3 tmux/tests/relay-keepers.py ~/desk/lab/relay-keepers-run
tmux/tools/tmux-lab run -- python3 tmux/tests/relay-native-lab.py ~/desk/lab/relay-native-run
```

Use a fresh output directory for each run. The first suite replays 52 saved empty/draft composer captures and tests exact routing on a private tmux server, including a colon session name, missing targets, sender/code preservation, automatic waiting for a draft, and an empty busy composer. Its three terminals are inert renderers. The second suite launches actual interactive Claude Code and Codex TUIs on the private server and records their exchange, a test-owned Codex draft, and input during a reply. Neither suite runs a headless Claude process.

Normal commands remain `cc-msg`, `codex-send`, `codex-send-to`, `agy-send-to`, and `relay <session>:<window> <text>`. Session names are resolved by exact name to tmux session IDs; the address separator is the last colon. Window names are resolved live. A draft causes automatic waiting, with the message record available through `relay status [id]`. Sender/window labels and short message codes travel in both direct text and archived pointers. Messages without a code receive one.

An explicit `--clear-draft` clears the named pane, `--operator` interrupts/clears before sending, and `--keys <keys...>` performs an explicitly requested TUI action on that pane. Normal messages never clear a draft. Source ancestry and an inherited live pane name supply attribution, without source binding or launch-form gates.

A submitted record confirms the tmux submission, not a model acknowledgment. After possible input, an error is recorded without replaying the message. Read the record and pane to resolve it.

The composer recognizer is shared with the model/reset commands. Their picker and reset tests remain under `codex-model-*` and `codex-new-*`. The specialized picker/reset operations remain separate from ordinary relay delivery.

Published captures use synthetic account identities and directories. ANSI sequences, widths and cursor geometry are preserved; manifest digests identify the sanitized bytes. Synthetic-derived cases retain their labels.
