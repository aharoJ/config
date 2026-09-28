# Changelog

## 2026-09-28 — Agent relays refuse drafts and never guess the session

`cc-msg.sh`, `codex-send` and `codex-send-to` in `tmux/tools/` typed into the target pane blind. Relayed text could land inside a half-typed message, and Enter submitted both. They also located the caller's session from `$TMUX_PANE`, which is stale inside Codex tool shells, so replies reached a Claude in another session (`libSZ:claude`). Each relay now reads the target's prompt line before sending. If it holds a draft, nothing is sent and the relay exits 5. Routing requires an explicit session (`CC_MSG_SESSION` plus `CC_MSG_WINDOW`, or `CODEX_SEND_SESSION`) and refuses with exit 1 on a missing or ambiguous target. The first version of the guard counted every idle box as a draft: the Codex check read the footer instead of the `›` line, and the idle CC prompt `❯` is followed by a non-breaking space. Both are fixed. `tmux/tests/relay-live-capture-regression.sh` covers the real styled Codex placeholder, the CC NBSP prompt, footer and status rows, and queued-row layouts. `~/.codex/AGENTS.md` and every project's `agent-tmux-operations.md` teach the new usage (outside this repo).

## 2026-09-28 — Codex renders inline so tmux scrollback works

Codex 0.157.1 defaults to `tui.fullscreen_transcript = true`, which enters the alternate screen and captures the mouse, so tmux wheel scrolling and copy mode could not reach its history. The fix is `tui.alternate_screen = "never"` in `~/.codex/config.toml` (outside this repo). It applies to every launch path: the fish wrapper, `command codex`, raw binary paths, other shells, and raw tmux commands. The interim `--no-alt-screen` wrapper flags in `fish/internal/codex/codex.fish` were reverted and the stray zsh alias removed. Verified in disposable tmux windows through `#{alternate_on}` and `#{mouse_any_flag}`: the default gives 1/1, and `alternate_screen = "never"`, `--no-alt-screen` or `fullscreen_transcript = false` each give 0/0. The composer and footer rows that pane-watch parses are unchanged, and the pane-watch regression suite passes. `codex --strict-config` accepts arbitrary values for this key, so it proves nothing about the setting.

## 2026-09-14 — Add tmux freeze capture and guided loop recovery

Added autoloaded fish functions `tfreeze` and `trescue` plus the narrow `tmux-loop-rescue --observe` interface. `tfreeze` captures new read-only evidence for the literal production socket without starting a missing server. `trescue` captures, observes, displays the fresh PID/build/count evidence, requires `RESCUE`, then leaves the exact PID confirmation to the rescue tool. It carries the fresh observed count forward automatically; there is no manual count prompt or maximum fallback.

The rescue write path now sets a fresh breakpoint and validates the stopped process, pinned executable identity, socket/process identity, breakpoint stop, selected frame, instruction, and current bounded counter immediately before any `w20` write. A failed final check skips the write and detaches where possible. This is only for the supported identity-matching cursor-down loop, not general tmux recovery.

## 2026-08-26 — Cap AI-agent process trees with `RLIMIT_NPROC`

Wired into every launcher: `claude.fish`, `deepseek.fish` (pinned 2.1.153 absolute path), `openrouter.fish` (→ qwen), `codex/codex.fish` (all three role branches), `kimi/kimi.fish`, `kimi/kimi-cli.fish`. New wrappers `agy.fish`, `gemini.fish`, `qwen.fish` cover three binaries that previously had **no** fish wrapper at all (fish history shows 7 `gemini`, 5 `qwen`, 2 `agy` real invocations). `cc.fish` needs no change — every role already funnels through the `claude` function. `tai` is covered for free: its tmux-created panes run these same functions.

Three design constraints, each of which broke a simpler version of this:

- **The limit must live in a disposable child, never the launcher's own shell.** Fish functions run in the interactive shell's process and hard limits are one-way, so `ulimit -H` in a function permanently caps that pane — verified, including `Permission denied` on restore. The helper instead runs `fish --no-config -c '…; exec $argv'` so the parent is untouched and `exec` collapses the child, leaving no extra process.
- **`--no-config` is load-bearing, not an optimization.** With config sourced, the child would populate `fish_function_path` and `exec claude` would resolve back to the *fish function* — infinite recursion. The helper also resolves `$argv[1]` to a real executable first (absolute path, else `command -s`).
- **Never put agent helpers in a new `internal/` subdirectory.** `fish_function_path` is a startup snapshot; running shells cannot see a directory created afterward, so edited launchers would call an unresolvable `_agent_limit` and every live pane's agent launch would break. Everything therefore lives in the already-listed `internal/claude/`.

`RLIMIT_NPROC` is compared against the **uid-wide** process count, not a per-tree quota — so this is a shared tripwire, not 2000 processes per agent. It works purely by asymmetry: agent trees sit at 2000 while interactive shells stay at 6000/9000, so when agents fill the table the operator's shell can still fork to diagnose and kill. For that reason it must never be applied in `config.fish` or any all-shells location. Baseline is ~577 uid processes, leaving ~1423 slots; a conservative 16-pane build model peaks near 1029.

Behaviour is otherwise unchanged: TTY, Ctrl+C/Ctrl+Z, exit status and argument passing are identical to unwrapped (verified in an isolated tmux server, including `--model claude-opus-4-6[1m]` and codex's `-c model_reasoning_effort="xhigh"`). The helper **fails open** — if the cap cannot be applied the agent still launches, so a platform quirk can never block work; the cost is that an unexpected loss of containment is silent. Tune with `AGENT_NPROC_CAP` (validated `^[0-9]+$`, so it cannot inject).

Rollout is staged and needs no action: new shells get full coverage; existing panes' autoloaded launchers reload "after a while" per fish's documented behaviour (not synchronously — do not promise next-invocation); `codex.fish` is *sourced* by `config.fish` so existing shells keep the old definition until re-source or replacement. Running agents are never affected — only future launches. **Do not restart tmux or re-source live panes to accelerate this.**

Known latent hole, not addressed here: tmux-resurrect snapshots raw agent command lines (`node <fnm>/codex …`, `claude --resume <uuid>`). It does not restore them today because `@resurrect-processes` is unset and the default allowlist excludes them — setting it to `:all:` would create an uncapped, wrapper-bypassing launch path from the tmux server.

## 2026-08-26 — Guard `yabaiQuery` against fork exhaustion

- `pcall(hs.execute, cmd)` catches the throw; the `status` check is kept **separately** because it catches a different failure — a yabai non-zero exit still returns normally (verified: `pcall(hs.execute, "exit 3")` → `ran=true, status=nil`, so `pcall` alone would silently swallow it).
- Failures are latched: the first one logs via `hs.printf`, repeats are suppressed until a successful query re-arms it. Silence was rejected — the original diagnosis was needlessly forensic precisely because the failure left no breadcrumb. Verified 4 failures → exactly 2 log lines across a re-arm.
- `stack-indicators.lua` needed no change: `getStacks()` returns nil, `draw()` already calls `cleanup()` before its `if not stack then return end`, so the degraded state is "pills disappear, watchers stay alive, next event redraws".

## 2026-05-28 — Add mimo target to `tai`

`tai` now accepts `mimo` as a first-class agent (`fish/internal/tmux/tai.fish`). Unlike the other agents, `mimo` isn't its own binary — it rides the `openrouter` wrapper, so the spawn maps to `openrouter --mimo-v2-flash` (→ `xiaomi/mimo-v2-flash`, the fast/paid model; wrapper defaults to `--approval-mode yolo`).

- New `__tai_command` helper resolves an agent label to its backing fish command (`mimo` → `openrouter`, everything else → itself) so the availability check tests the real command.
- Added `mimo` to the `all` set, the target `switch`, the usage line, and the completion list.

Note: `tai all` now spawns **5** windows including the paid-per-token mimo window. To keep mimo out of `all` while still allowing `tai mimo`, drop `mimo` from the `set -l agents …` line.

## 2026-05-27 — Restore mimo flags in openrouter wrapper

Re-added two Xiaomi MiMo model flags to `fish/internal/claude/openrouter.fish`. They had only ever existed as uncommitted local edits (git history confirms `mimo` was never committed to the file), so they were lost when the wrapper was rewritten — same failure mode as the earlier `tai` restore. Recovered the exact model IDs from `~/.qwen` telemetry (both returned HTTP 200 the same day):

- `--mimo-v2-flash` → `xiaomi/mimo-v2-flash` (paid, fast)
- `--mimo-v2.5-pro` → `xiaomi/mimo-v2.5-pro` (paid, heavy)

Restored across all four flag-list sites (model resolver, allow-guard, usage text, strip loop). Single-model-flag enforcement and cost-safety guards unchanged.

**Follow-up (same day):** wrapper now **defaults to `--approval-mode yolo`** (auto-approve every tool, no prompts) — the bare prompt-on-everything default made the agents unusable. The default is skipped when the caller passes their own `-y` / `--yolo` / `--approval-mode ...`, so per-call override (e.g. `--approval-mode plan`) still works.

## 2026-03-19 — Hammerspoon Nuke & Rebuild + Claude Code Keybindings

Nuked the old GPT/Grok-built stackline (~2,500 lines) and rebuilt Hammerspoon from scratch (~150 lines). Moved config into dotfiles repo. Also tweaked Claude Code keybindings and default modes.

### Hammerspoon

1. **`hammerspoon/`** — New clean config with modular architecture (`init.lua`, `modules/reload.lua`, `modules/stack-indicators.lua`, `modules/utils.lua`)
2. **Stack indicators** — App icon pills on window edges for yabai stacks. Queries current space only, groups by `stack-index`, theme-aware (light/dark), click-to-focus
3. **Symlink** — `~/.hammerspoon/init.lua → ~/.config/hammerspoon/init.lua` so config is tracked in dotfiles
4. **Auto-reload** — Pathwatcher reloads on any `.lua` file save. IPC enabled for `hs` CLI commands
5. **`fish/internal/yabai/yr.fish`** — Added `hs -c "hs.reload()"` so Hyper+Q reloads hammerspoon alongside yabai + skhd

### Claude Code

6. **`~/.claude/keybindings.json`** — Rebound `Tab → chat:cycleMode` (was Shift+Tab), unbound Shift+Tab
7. **`~/.claude/settings.json`** — Default to plan mode + bypass permissions

## 2026-03-18 — Pre-commit Secret Scanner

Added a 3-layer pre-commit hook (ported from `~/.notes/`) to prevent accidental secret leaks in this public repo.

### Changes

1. **`.pre-commit-hook`** — Source template with path blocking (`stripe/`, `gh/`), content scanning (31 patterns), and allowlist support
2. **`.hook-allowlist`** — Initial allowlist (the hook file itself)
3. **`.gitignore`** — Added `stripe/` (Stripe CLI credentials directory)
4. **`CLAUDE.md`** — Documented hook architecture and post-clone install step

## 2026-02-26 — Fish Notes System Audit & Patch

Multi-model audit (lead_triage, deepseek, gemini-lite, gpt-nano, grok) across 2 passes, 86 findings triaged. 25 edits applied across 14 files.

### Critical fixes (showstoppers)

1. **nleitner.fish**: `<=` → `not test \>` in `_nleitner_run` and `_nleitner_status` — cards were NEVER showing as due (Fish `test` has no `<=` operator)
2. **nsync.fish**: `\s*` → `[[:space:]]*` in pre-commit hook — secret detection was non-functional on macOS (POSIX ERE doesn't support `\s`)

### Correctness fixes

3. **__notes_require.fish**: Added `-w` writable check for `NOTES_DIR`
4. **note.fish**: Added error check for `_notes_ensure_journal` failure
5. **nq.fish**: Robust error handling for journal creation + empty entry after sanitization guard
6. **nleitner.fish**: Deck name validation (reject slashes/dots = path traversal prevention)
7. **nleitner.fish**: Q/A count mismatch guard before drilling
8. **nleitner.fish**: `_nleitner_date_add` fallback when both date forms fail
9. **nleitner.fish**: Check `_nleitner_reconcile` return status
10. **nleitner.fish**: Empty deck name validation
11. **nleitner.fish**: Check `mkdir` return status for deck/state dirs
12. **nrate.fish**: Validate tmp file non-empty before `mv` (prevents note destruction)
13. **nrate.fish**: File existence check before awk
14. **nerror.fish**: Fix fzf preview path (was losing directory via `basename`)
15. **npresleep.fish**: Resolve paths to absolute before dedup check
16. **npresleep.fish**: Read queue line-by-line instead of command substitution

### Robustness fixes (unchecked mkdir)

17-21. **ncalibrate.fish, nerror.fish, nstruggle.fish, nwhy.fish, nrecall.fish**: All now check `mkdir -p` return status

### UX fixes

22. **ninterleave.fish**: Quit prompt accepts Q/q with whitespace trimming
23. **ninterleave.fish**: Check awk availability before shuffling

### Declined / not applicable (reviewed, no action needed)

- `$EDITOR` fallback (P3 — always set in `config.fish`)
- `seq` availability (ships with macOS)
- `__notes_slug` char coverage (current set covers all dangerous chars for APFS)
- `nf` cd not returning (by design — note functions operate in `$NOTES_DIR`)
- `git pull --rebase` (intentional, documented)
- Pre-commit hook "bashisms" (false positive — hook is pure POSIX sh)
