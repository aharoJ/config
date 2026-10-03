# Changelog

## 2026-10-03 — Sanitize public configuration and restore reproducible loading

Sanitized terminal fixtures while preserving rendering geometry, refreshed fixture digests, removed deployment details, added a staged privacy gate, made profile links portable, and included the Neovim tools plugin specifications.

## 2026-10-03 — Recognize equivalent fresh-home ANSI renders

Fresh Codex home recognition now checks the supported visible layout instead of literal greeting and tip SGR prefixes. Redundant resets, reordered attributes and equivalent reset placement no longer reject a fresh home. The input/draft guard and menu-highlight proof remain unchanged. Byte-exact live reset coverage and intensity-preserving ANSI variants cover accepted homes/menus, drafts, unfamiliar screens and retained-transcript counterexamples.

## 2026-10-02 — Verify fresh Codex chats outside git

`codex-new-chat` now accepts the observed fresh home screen that `/new` displays outside a git repository, alongside the existing current-checkout menu. Both paths retain the same identity, cwd, zero-context, model/effort restoration, and idle-composer checks before reporting success, and additionally require the supported home-screen grammar, refusing retained conversation text even beside a zero-context footer. An unfamiliar transition still returns an unverified result without further input.

## 2026-10-02 — Own private tmux lab fixtures

`tmux-lab run -- <command>` owns one isolated private server, restricts child tmux requests to that server, records process and socket identities, and verifies teardown on completion or interruption. Detached descendants are checked through their macOS responsibility scope; survivors and interrupted owners remain visible in the read-only `tmux-lab ls` ledger and listener census. The paste-collision fixture now uses the supplied owner when wrapped and waits for a stable, guard-accepted empty composer, so a workspace-trust dialog cannot masquerade as readiness. Focused regression coverage checks lifecycle, isolation, escaped descendants, signal handling, reused names, and independent live-server accounting.

## 2026-10-02 — Retire obsolete config scripts links

The config cross-review links to `~/.notes` were dangling after that tooling moved to `~/.notes/idle`. Removed the obsolete config-local usage instructions and ignore entries as part of the scripts-directory retirement. Relay users now use the stable `~/.local/bin/cc-msg` entry point; tracked source remains under `tmux/tools/`.

## 2026-10-02 — Relay red team 2 repairs

Captured idle states at narrow Claude, Agy and Codex widths now pass their composer guards. Relay payloads paste in one guarded operation, avoiding an unguarded second chunk. Relay locks require a valid tmux socket identity, and route names compare as strings. Codex preflight uses its observed one-row margin and refuses characters whose rendered width the installed Unicode table cannot prove. Draft or unknown-state refusals now say both possibilities.

With explicit approval, `codex-send`, `codex-send-to` and `agy-send-to` refuse messages starting with `/` or `!` after normalization, before target input. `cc-msg.sh` retains its sender-prefixed behavior. Disposable Codex and Agy panes refused both leading characters with byte-identical before/after captures and delivered an inert message containing `/` and `!` later in the text.

The composer guard now accepts workload-dependent dim suggestions regardless of their wording, and ignores text below a proven footer boundary. Normal-intensity draft text still refuses. A verified Claude Code sender uses the relaxed tier for an ambiguous unstyled Home state; Codex, agy, DeepSeek, and unresolved senders use the strict tier. A fresh sender pane identity and Claude model status are required for the relaxed tier. Relay exits now distinguish known no-write refusals from potentially partial delivery, with busy contention returning 5 and route changes returning 1. A second preflight and a settled full-composer check precede Enter; the same-tick Enter race remains a documented residual.

Wrapped all-dim suggestions are accepted when their full composer boundary is proven; bright or whitespace-only continuation drafts still refuse. Active near-prompt work indicators cause strict senders to exit 5 before input, while historical completed work remains sendable. Refusal diagnostics identify live slash menus and Agy exit warnings instead of treating both as drafts.

A synthetic-derived Codex workload hint fixture changes only text inside the dim span of a real idle capture and preserves its styling and cursor metadata. Real `✻ Hashing…` and `✶ Warping…` Claude captures, plus an Agy generating capture, guard the sender-aware busy path. A real dynamic Codex hint remains pending for a read-only capture when it appears.

Every targeted `display-message` relay read and paste/Enter receipt now echoes the immutable pane ID and checks it against the resolved target. tmux can return exit 0 with another pane's data for a vanished `-t` target. Pane-watch pins its initial target with `list-panes` and checks the pane ID on each metadata and geometry read. Private-server target-death and replacement races refused without input or reported an unknown outcome after a paste; none claimed delivery to the replacement.

A fresh blind race found that a human could type an Agy draft and move Home between the empty check and the first paste, preserving the original cursor coordinates; the relay pasted into that draft and exited 4. Codex and Agy now bind the first paste to the exact visible input row inside tmux's conditional guard. Claude's empty NBSP prompt is not searchable by tmux's pane-content operator, so its paste path takes a fresh app-guarded capture immediately before a nested identity/cursor guard. A separate blind proxy found that duplicate Codex history skipped the Enter row check; repeated identical sends now use a fresh active-row capture before guarded Enter. The accepted final scheduling interval between the last capture and Enter remains documented as a residual.

## 2026-10-01 — Agent launches recover from a deleted fnm link

An fnm multishell cleanup moved every open fish shell's live link to the Trash, so codex, gemini and qwen launched through `_agent_limit` failed as "not found". `_agent_limit` now detects a missing `$FNM_MULTISHELL_PATH`, drops the dead `fnm_multishells` entries from PATH, re-sources `fnm env --use-on-cd`, prints a one-line notice and resolves the agent as before. Older panes still need `exec fish` to recover node and npm.

## 2026-10-01 — Accept Claude's empty post-delete hint

The blind live round found an empty DeepSeek composer refused after clearing a draft: its status row added `Ctrl+Y to paste deleted text` after the version. The exact styled capture is now a must-accept fixture. The guard accepts only that observed suffix; other status text still refuses.

## 2026-10-01 — Add guarded Agy panel delivery

`agy-send-to` delivers one-row messages to an explicitly named Agy window in an explicit session, with an optional numeric pane ID for a multi-pane window. It uses the shared relay lock, identity and resize checks, buffered paste, complete composer verification and conditional Enter. The Agy input guard recognizes the captured blue `>` prompt between full-width dividers and its idle shortcuts footer. Real Home-moved text and whitespace drafts, an open slash menu and a wrapped draft refused without a paste. Idle sends passed at 167 and 19 columns. Six real Agy idle captures were added to the must-accept gate, and the staged drafts to the must-refuse set. The helper is linked from `~/.local/bin/agy-send-to`.

## 2026-10-01 — Restore Claude relay delivery after false draft refusals

Live red teaming found a P0 in an intermediate candidate: a divider-shaped line inside a real multiline DeepSeek draft fooled the guard and `cc-msg.sh` pasted into the draft before stopping with exit 4. The exact pre-paste capture is a must-refuse fixture. The guard now rejects a later divider and requires the observed Claude status and permissions mode rows immediately after the first divider, with the version checked when the full status fits. The same staged live attack then exited 5 without changing the pane; idle delivery still exited 0.

Narrow live panes exposed two availability edges: truncated Claude status rows made empty 40- and 19-column panes refuse, and the 19-column payload verifier rejected a correctly pasted short message because it required a 20-character divider. The input guard now compares the divider with the verified pane width, and the payload verifier uses that width too. Claude capacity reserves one extra cursor cell so a right-edge message refuses before paste.

## 2026-10-01 — Relays survive Codex UI drift and are red-teamed before landing

A stress run hardened the relay tools in 27 commits (`d6d24bb`..`a3e40ed`), each pairing one reproduced finding with one regression test.

- **Test harness:** it now fails closed before any request can reach the default tmux server.
- **Composer checks:** footer and draft detection reject unstructured styled boundaries, colon SGR resets, and dividers inside Claude drafts. Composer bytes, pane identity, geometry and cursor are rechecked immediately before Enter.
- **Interrupted sends:** INT, TERM and PIPE are reported at every stage of a send.
- **Rescue tooling:** `tmux-loop-rescue` refuses lab socket path escapes, production overrides and future-dated observations.
- **pane-watch:** it refuses missing or invalid option values and namespaces its locks per private server.
- **Freeze capture:** it stops after a tmux timeout and writes owner-only evidence.

Before the harness guard existed, early tests sent six read-only `list-panes` queries and six `lsof` checks to the default socket. No input, reload or server control was sent. Relay scratch cleanup briefly moved to `rm` and was restored to `trash` (`163223f`), because a recoverable copy is preferred. A failed Trash operation now prints a cleanup-unconfirmed notice without changing exit codes.

`b70cef8` introduced a strict Codex footer grammar that did not know the ` · Main [default]` segment. Codex adds that segment after a session uses subagents. Every relay to such a pane, on every desk, refused an empty composer with exit 5.

- `efecb4f` taught the input guard the segment, but not the post-paste payload verifier. Payloads were therefore typed correctly and then held with exit 4, with no Enter sent.
- `a19b07f` accepted a cleared-composer capture that the timeline later showed was a one-space draft. That capture is now a must-refuse fixture. Keyboard evidence from a real Codex 0.159.3 distinguishes the two states: Space then Home leaves a bare prompt, while End then Backspace restores the placeholder.
- `2381d7f` landed before the design converged.
- `de1d538` is the converged fix:
  - Both guards accept the observed `Main [default]`, reconnect and no-`Context` Terra footers.
  - Numeric SGR attributes are normalized before classification, so zero-padded conceal codes and conceal styling refuse.
  - A bounded Enter retry fires only on tmux's exact no-write refusal, after rechecking identity, geometry, cursor and the payload row. A relay never prints `SENT` without a verified submission receipt.
  - The design is deliberately fail-closed: unfamiliar visual states refuse, and the operator types by hand.

`relay-live-capture-regression.sh` is now a pre-landing gate. It requires a stable six-state manifest of real Codex 0.159.3 screens:

- fresh, post-subagent and working composers must be accepted
- single-line, multiline and Home-moved drafts must refuse

A second red-team round ran with no inherited context against the final candidate. It found dim and whitespace continuations, conceal styling, non-SGR controls on trusted boundaries, weak Home-draft semantics in the gate, and overstated fixture provenance; all are fixed. The final tree passes:

- 74 guard checks
- 300 fuzz iterations
- 34 stress tests
- 83 state/race cases
- 196 delivery cases
- the six-state live gate

The fix was also checked on production panes. The guard accepted all six real Codex panes across the config, v3-51-walker, portfolio and INFRA sessions, and one real `codex-send` reached a `Main [default]` pane.

Codex messages labelled `relay:` are by design. Codex runs commands under detached app-server processes, and no authenticated ancestry leads back to a pane. Still open, as proposals only:

- an opt-in `AGENT_PANE_EXEC` launch for fish-wrapped panes, which `tai` already makes mostly unnecessary
- an `agy` send helper for Gemini
- a relay lock-protocol redesign

## 2026-09-30 — Relays recognize Codex 0.159.2 status and busy footers

Codex 0.159.2 renders its status footer without the foreground/background color sequences that both relay guards previously required. An empty composer therefore exited 5 as a false draft, and a typed payload could exit 4 without Enter. The guards now recognize the captured footer's complete Fast/model/directory/context fields, optional agent or warning controls, and its position after one blank row below the composer. Cursor advancement and real draft detection remain unchanged.

Busy Codex also replaces the status line with `tab to queue message` and the remaining context count after text is pasted. Exact payload verification now recognizes that captured boundary; it still requires the complete text, cursor, target identity, and dimensions to agree twice before one Enter. Altered, hidden, wrapped, cropped, or unfamiliar input still fails closed. Real Codex 0.159.2 startup, idle, draft, busy, and session-only model-change captures are committed as regression fixtures. Both public Codex relays exercise these layouts and hostile busy receivers in the expanded private-server matrix, with Codex 0.157.1 compatibility retained.

## 2026-09-30 — Claude relay labels identify the calling agent and pane

`cc-msg.sh` previously prefixed every message with `codex:`, including messages sent by Claude Code. It now matches the caller's live process ancestry to tmux's pane process, identifies native Claude/Codex binaries and their Node entry points, repeats the process check, and rechecks the pane's session, window, process, and live state before using labels such as `claude (INFRA:claude):`. Inherited `TMUX_PANE` and `CC_MSG_FROM` values cannot supply the identity. Unknown, ambiguous, changed, or untraceable origins use a neutral `relay` label; a shared Codex daemon without ancestry back to a pane remains neutral.

The complete prefix still counts toward the one-row capacity limit. Bracketed paste, two exact composer checks, one Enter, explicit target routing, draft/copy refusal, exits 0–5, and clipboard avoidance are unchanged. The private-server regression matrix now covers both agents, Node launchers, stale pane ids, ignored overrides, neutral fallback, linked/renamed sender panes, prefix capacity, resizing, and pane death. Real interactive lab TUIs also exercised all four send directions and refusal paths; the existing input-guard, live-capture, and pane-watch regressions passed. Codex 0.159.2's unstyled footer is still refused by the existing input guard; supported Codex 0.157.1 screens were used for successful live delivery tests.

## 2026-09-30 — Agent relays verify the complete composer and refuse long text

`cc-msg.sh`, `codex-send`, and `codex-send-to` previously reported delivery when tmux executed an input command, even if the agent lost most of the text. A live Claude Code reproduction retained only 628 of 1,650 normalized bytes while the original helper reported success. The same payload reached a raw terminal intact, and bracketed paste preserved the full text in Claude's persisted transcript.

All three relays now use named tmux buffers and bracketed paste, compare the entire active composer and its cursor against the normalized payload twice, then send one Enter. Wrapped or oversized messages are refused before typing: terminal wrapping cannot prove that every whitespace byte survived, so long output must be sent as a short file reference. Missing, altered, hidden, or unfamiliar input exits nonzero without Enter. Copy mode and exact target identity are checked atomically for every input operation; exits 0–5, draft refusal, shared sender locks, and the distinction between delivery and acknowledgment remain intact. UTF-8 validation also rejects control characters and NULs from stdin. Verification ignores unrelated startup hyperlinks above the composer, which previously caused false refusals for exact messages.

## 2026-09-28 — Agent relays refuse drafts and never guess the session

`cc-msg.sh`, `codex-send` and `codex-send-to` in `tmux/tools/` typed into the target pane blind. Relayed text could land inside a half-typed message, and Enter submitted both. They also located the caller's session from `$TMUX_PANE`, which is stale inside Codex tool shells, so replies reached a Claude in another session (`libSZ:claude`). Each relay now reads the target's prompt line before sending. If it holds a draft, nothing is sent and the relay exits 5. Routing requires an explicit session (`CC_MSG_SESSION` plus `CC_MSG_WINDOW`, or `CODEX_SEND_SESSION`) and refuses with exit 1 on a missing or ambiguous target. The first version of the guard counted every idle box as a draft: the Codex check read the footer instead of the `›` line, and the idle CC prompt `❯` is followed by a non-breaking space. Both are fixed. `tmux/tests/relay-live-capture-regression.sh` covers the real styled Codex placeholder, the CC NBSP prompt, footer and status rows, and queued-row layouts. `~/.codex/AGENTS.md` and every project's `agent-tmux-operations.md` teach the new usage (outside this repo).

## 2026-09-28 — Codex renders inline so tmux scrollback works

Codex 0.157.1 defaults to `tui.fullscreen_transcript = true`, which enters the alternate screen and captures the mouse, so tmux wheel scrolling and copy mode could not reach its history. The fix is `tui.alternate_screen = "never"` in `~/.codex/config.toml` (outside this repo). It applies to every launch path: the fish wrapper, `command codex`, raw binary paths, other shells, and raw tmux commands. The interim `--no-alt-screen` wrapper flags in `fish/internal/codex/codex.fish` were reverted and the stray zsh alias removed. Verified in disposable tmux windows through `#{alternate_on}` and `#{mouse_any_flag}`: the default gives 1/1, and `alternate_screen = "never"`, `--no-alt-screen` or `fullscreen_transcript = false` each give 0/0. The composer and footer rows that pane-watch parses are unchanged, and the pane-watch regression suite passes. `codex --strict-config` accepts arbitrary values for this key, so it proves nothing about the setting.

## 2026-09-17 — Tmux freeze captures default to external storage

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

## 2026-03-25–29 — Network tooling hardening

Improved device discovery, DNS handling, wake-on-LAN, guest-network isolation, monitoring and input validation. Deployment identifiers and household network details are omitted from the public changelog.

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
