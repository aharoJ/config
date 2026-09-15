# 🐋 WHALE — dotfiles rebuild tracker

The single source of truth. If it is not in this file, it is not happening.

**Blank slate.** The workshop is empty. Nothing is ported. Anything that comes back is typed from scratch, because Angel missed it. What never comes back was never important.

The old tree is a museum: read it, never copy it. Live `~/.config` keeps running until a lane is promoted.

---

## ▶ NOW

| Field       | Value                                                                  |
| ----------- | ---------------------------------------------------------------------- |
| Lane        | 1 · Ghostty                                                            |
| Status      | ⏸ waiting on Angel                                                     |
| Next action | Angel says what a fresh Ghostty should feel like; then preview preflight |
| Blocked by  | Angel                                                                  |

---

## 📋 QUEUE — first to last

| #   | Lane                     | Built from scratch in `~/.config-next`                                            | Status | Done looks like                                                                                   |
| --- | ------------------------ | --------------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------- |
| 0   | Foundation               | tag + worktree + empty workshop                                                   | ✅     | tag `dotfiles-before-redesign-2026-09-15`; workshop holds only this file                          |
| 0.5 | 🐟 Fish break list       | read-only audit of what calls into fish                                           | ✅     | BREAK LIST below: what dies the moment fish is empty                                              |
| 1   | Ghostty                  | `ghostty/`                                                                        | ⏸      | _Angel defines_                                                                                   |
| 2   | Alacritty decision       | `alacritty/`                                                                      | ⏳     | rebuilt from zero, or left dead                                                                   |
| 3   | Starship                 | `starship/`                                                                       | ⏳     | _Angel defines_                                                                                   |
| 4   | Yazi                     | `yazi/` + its fish entry points                                                   | ⏳     | _Angel defines_                                                                                   |
| 5   | eza + git                | `eza/` `git/` + its fish entry points                                             | ⏳     | _Angel defines_                                                                                   |
| 6   | 🐟 Fish core             | `fish/` minus what other lanes claim                                              | ⏳     | _Angel defines_                                                                                   |
| 7   | tmux                     | `tmux.conf` from zero; `tmux/tools/` survives untouched                           | ⏳     | _Angel defines_                                                                                   |
| 8   | Hammerspoon              | `hammerspoon/`                                                                    | ⏳     | _Angel defines_                                                                                   |
| 9   | yabai + skhd + Karabiner | `yabai/` `skhd/` `karabiner/` + their fish entry points                           | ⏳     | _Angel defines_                                                                                   |
| 10  | Root sweep               | repo root and docs                                                                | ⏳     | root holds only what belongs; README/CLAUDE.md describe the new house                             |
| 11  | 🐋 Neovim                | `nvim/` + its fish entry points                                                   | 🔒     | separate 2026–27 project; locked until then                                                       |

Status: ✅ done · ▶ in progress · ⏸ waiting on Angel · ⏳ queued · 🔒 locked

---

## 🛡 GUARDRAILS

1. Nothing is ported. Each lane starts from an empty file and grows only by what Angel misses in real use.
2. The museum is read-only reference. Look at the old config to remember a setting; never copy a file out of it.
3. One lane, one bounded promotion set, one preview, one promotion commit, one easy revert.
4. Live `~/.config` changes only by promotion, only after Angel approves.
5. No lane starts until the one above it is ✅ or Angel reorders this file.
6. Something new comes up → it goes into PARKED. It does not start.
7. Promotion deletes live tracked files that the workshop no longer has, which is the point. Untracked local files survive it. Never `git clean`, `checkout -f`, or force anything.
8. **Survives the nuke:** `tmux/tools/` (`tmux-freeze-capture.fish`, `tmux-loop-rescue`, `cc-msg.sh`, `codex-send`, `codex-send-to`, `pane-watch/`) and the live-only `fish/conf.d/secrets.local.fish`. Configs around them are fair game.
9. Public repo: no secrets, no private evidence. Environment and credential entries by name only, never by value.
10. Minimal comments. A fresh config should be obvious without them.
11. Neovim stays locked until lane 11, including its fish entry points and aliases.
12. Fish entry points for a tool are rebuilt in that tool's lane; lane 6 owns only what no other lane claims.

---

## 🔁 LANE LOOP

- [ ] Contract: what a fresh one should feel like · smoke test · rollback
- [ ] Read this lane's row in BREAK LIST; decide for each entry point: rebuild it, or let it die
- [ ] Preview method proven for the installed app version before writing anything
- [ ] Create the folder empty in `~/.config-next` and start from defaults
- [ ] Add only what is missed in real use, one thing at a time
- [ ] Side-by-side preview
- [ ] Smoke test on real work
- [ ] Commit on `rebuild/dotfiles`
- [ ] Angel approves promotion
- [ ] Confirm the live folder has no unreviewed modification, and note which untracked files will survive
- [ ] `git -C ~/.config restore --source rebuild/dotfiles --staged --worktree -- <tool>/`
- [ ] Review `git -C ~/.config diff --staged` · commit on `development` with a CHANGELOG entry · reload the app
- [ ] Live with it · keep or `git revert`
- [ ] `git -C ~/.config-next rebase development`
- [ ] Mark ✅ here, add a LOG line, move NOW to the next lane

---

## 🏛 MUSEUM — the old tree, read-only

| Need                    | Command                                                                        |
| ----------------------- | ------------------------------------------------------------------------------- |
| List the old files      | `git -C ~/.config ls-tree -r --name-only dotfiles-before-redesign-2026-09-15`   |
| Read one old file       | `git -C ~/.config show dotfiles-before-redesign-2026-09-15:ghostty/config`      |
| See a setting's history | `git -C ~/.config log -p --all -- <path>`                                        |
| The live copy           | still running in `~/.config` until that lane is promoted                        |

---

## 🎯 ACTIVE LANE

### Lane 1 · Ghostty

- [ ] Contract
  - Done looks like:
  - Smoke test:
  - Rollback: `git revert <promotion commit>`; Ghostty reloads on save
- [ ] Preview preflight — `+show-config --config-default-files=false --config-file=…` returned rc=1 on 1.3.1
- [ ] Empty `ghostty/config`, defaults only
- [ ] Add back only what is missed
- [ ] Preview
- [ ] Smoke test
- [ ] Commit on `rebuild/dotfiles`
- [ ] Promote `ghostty/` (after approval) — retires `config.bak`, `config.bak.2` with it
- [ ] Rebase `~/.config-next`

---

## 🐟 BREAK LIST — what dies the moment fish is empty

From the lane 0.5 read-only audit. Line references point at the live tree and the museum tag.

### Startup chain — static only

| Order | Contract | Evidence |
| --- | --- | --- |
| 0 | Fish runtime handling of universal variables and `conf.d` precedes this file only by Fish semantics; exact order is **UNVERIFIED** because this audit did not start Fish. | `fish/fish_variables:1-14`; `fish/conf.d/fzf.fish:1-14`; `fish/conf.d/rustup.fish:1`; `fish/conf.d/sponge.fish:1-52`; `fish/conf.d/z.fish:1-46` |
| 1 | Global startup exports `STARSHIP_CONFIG`, `EZA_CONFIG_DIR`, `PYENV_ROOT`, `BASH_ENV`, `EDITOR`, and `VISUAL`; Homebrew and pyenv mutate `PATH`. | `fish/config.fish:4-42` |
| 2 | `config.fish` prepends every `internal/*/` directory to `fish_function_path`, then eagerly sources the Codex wrapper. | `fish/config.fish:50-65` |
| 3 | Interactive shells initialize Starship, source the Gruvbox theme, lazily integrate jenv, initialize fnm, hook direnv, define eza aliases/abbrs/binding, and keep `n`/`nvim-v3` aliases. | `fish/config.fish:68-159` |
| 4 | All shells add Kimi and local-bin paths after the interactive block. `fish_plugins` is a Fisher manifest, not a startup install command. | `fish/config.fish:166-180`; `fish/fish_plugins:1-4`; `fish/functions/fisher.fish:1` |

### Per-lane break contract

| Lane | Fish surface and entry points | Must keep working, or die on purpose | Evidence |
| --- | --- | --- | --- |
| 1 Ghostty | No Fish-owned file. Ghostty detects shell integration but does not statically select Fish. | `SHELL`/login-shell route **UNKNOWN**; a new Ghostty terminal must reach the expected interactive Fish prompt. | `ghostty/config:90-99` |
| 2 Alacritty | Alacritty directly starts Fish. | `/opt/homebrew/bin/fish` remains executable; a new Alacritty window starts cleanly. | `alacritty/alacritty.toml:104-105` |
| 3 Starship | Fish exports `STARSHIP_CONFIG` and pipes `starship init fish` into `source`. | `STARSHIP_CONFIG`; interactive prompt and theme render. | `fish/config.fish:4,68-75` |
| 4 Yazi | `yazi` preserves cwd through a temp file; `lf` starts Neovim's current rebuild with Yazi. | `NVIM_APPNAME`; `yazi` returns to selected cwd and `lf` opens the expected editor route. | `fish/functions/yazi.fish:2-12`; `fish/internal/yazi/lf.fish:2-4` |
| 5 eza + git | eza aliases are `ls la ll ld lr lt`; `set-eza-theme` reads and writes the eza theme link. No Git-owned Fish entry point was found. | `EZA_CONFIG_DIR`; aliases and selector work; Git-oriented fzf helpers remain available. | `fish/config.fish:5,140-147`; `fish/internal/eza/set-eza-theme.fish:1-22`; `fish/functions/_fzf_search_git_status.fish:1` |
| 6 Fish core | Owns everything below not claimed by another lane; detailed ledger follows. | Preserve noninteractive and interactive startup. | `fish/config.fish:4-180` |
| 7 tmux | `t`, `tn`, `tK`, `tai`, `tfreeze`, `trescue`; `tai` launches a login Fish in new agent panes. | `TMUX`, `TMUX_FREEZE_CAPTURE_*`, `TMUX_SHORTCUTS_LAB_*`; emergency safeguards remain intact. | `fish/internal/tmux/t.fish:1-8`; `fish/internal/tmux/tai.fish:86-109`; `fish/internal/tmux/tfreeze.fish:1-69`; `fish/internal/tmux/trescue.fish:1-75` |
| 8 Hammerspoon | No Fish-owned surface or static direct caller found. | Runtime coupling **UNKNOWN**; do not infer a safe change from static absence. | `UNKNOWN (static scan: hammerspoon/)` |
| 9 yabai + skhd + Karabiner | `ys yk yp yr _swap_skhd_profile sk skr`; skhd invokes `fish -c` for `yr` and `yp`. | `HOME`, `PATH`; service and profile hotkeys still resolve Fish and their functions. | `fish/internal/yabai/yp.fish:13-62`; `fish/internal/yabai/yr.fish:13-111`; `fish/internal/skhd/sk.fish:3-10`; `skhd/skhdrc:45-67`; `skhd/modules/shared/services.skhdrc:6-25` |
| 10 Root sweep | No Fish surface is owned; docs retain a manual source instruction. | External callers stay inventory-only. | `CLAUDE.md:13,41-45` |
| 11 Neovim 🔒 | Locked: `v`, `vim`, plus `n` and `nvim-v3` aliases; Neovim itself selects Fish as shell. | `NVIM_APPNAME`; plain `nvim`, `n`, `v`, and `vim` retain their current routes until lane 11. | `fish/internal/nvim/v.fish:2-9`; `fish/internal/nvim/vim.fish:2-9`; `fish/config.fish:158-159`; `nvim-rebuild/lua/core/options.lua:75` |

### Lane 6 core ledger

| Area | Owned contract | Evidence |
| --- | --- | --- |
| Agent boundary | `_agent_limit` caps child agent trees; wrappers are `claude cc cu agy gemini qwen deepseek openrouter codex kimi kimi-cli`. Preserve `AGENT_NPROC_CAP`. Credential and routing variables are referenced by family only: the DeepSeek and OpenAI provider key variables, the Anthropic variable family, the OpenAI base-URL variable, and the Claude subagent-model variable. | `fish/internal/claude/_agent_limit.fish:31-64`; `fish/internal/claude/claude.fish:8-14`; `fish/internal/claude/cc.fish:2-58`; `fish/internal/claude/deepseek.fish:1-53`; `fish/internal/claude/openrouter.fish:1-101`; `fish/internal/codex/codex.fish:1-48`; `fish/internal/kimi/kimi.fish:34-38` |
| System helpers | `bu`; `net`; Python/pyenv wrappers; `freeport sbr sbt sr st`; `trash-pick`; tracked dormant `vscode/c.txt`; project worktree helpers `cvmapp-wt* cwt rp-wt* rwt stage-wt* swt swt-close`. Home-level tool roots and `PATH` are dependencies. | `fish/internal/brew/bu.fish:1-2`; `fish/internal/net/net.fish:46-52,323,528`; `fish/internal/python/_pyenv_lazy_init.fish:1-4`; `fish/internal/spring-boot/freeport.fish:1-13`; `fish/internal/worktree/stage/stage-wt.fish:1` |
| Interactive UX | Fisher-managed `fzf`, `sponge`, and `z` functions/conf.d, generic completions, Gruvbox theme, `..`/`...`, and Ctrl-D binding belong here; `yazi.fish` is lane 4. Variables: `Z_DATA`, `Z_DATA_DIR`, `Z_CMD`, `ZO_CMD`, `Z_EXCLUDE`, `sponge_*`, `fish_key_bindings`. | `fish/conf.d/fzf.fish:1-21`; `fish/conf.d/sponge.fish:1-52`; `fish/conf.d/z.fish:1-46`; `fish/config.fish:73-75,149-155`; `fish/fish_plugins:1-4` |

### External caller ledger

| Caller | Contract | Evidence |
| --- | --- | --- |
| Alacritty | Directly execs Fish, so every Fish startup regression is an Alacritty regression. | `alacritty/alacritty.toml:104-105` |
| skhd | Root uses Bash, shared service bindings explicitly run `fish -c "yr"` and `fish -c "yp …"`; changing autoload/path breaks hotkeys. | `skhd/skhdrc:45-61`; `skhd/modules/shared/services.skhdrc:6-25` |
| Neovim | Sets its shell to Fish; shell commands depend on Fish startup. | `nvim-rebuild/lua/core/options.lua:75` |
| tmux emergency path | Fish functions call the Fish capture script through absolute tmux-tool paths. | `fish/internal/tmux/tfreeze.fish:7-10,62-69`; `fish/internal/tmux/trescue.fish:7-10,64-75`; `tmux/tools/tmux-freeze-capture.fish:1,53` |
| External repair script | `~/.scripts/fix-effort.sh` invokes Fish and mutates live Fish state/source; it is outside this repo but must be inventoried before any variable or path redesign. | `~/.scripts/fix-effort.sh:6,10,14-15,22-23` |
| Scan boundary | No static direct invocation was found in `hammerspoon/`, `yabai/`, `karabiner/`, `yazi/`, active `tmux/tmux.conf`, `git/`, `~/.local/bin`, LaunchAgents, or current Claude/Codex settings/statusline files; runtime/system callers remain **UNKNOWN**. | `UNKNOWN (static search only)` |

### Preview hazards and live-only state

| Item | Hazard | Evidence |
| --- | --- | --- |
| Live-root leaks | The old config hardcodes the live Fish internal root, Codex source, theme, Starship, and eza paths; an XDG-only preview would load live behavior. A fresh fish must resolve its own root. | `fish/config.fish:4-5,50-65,73-75` |
| Home-level tools | pyenv, `BASH_ENV`, jenv, fnm, direnv, Cargo, Kimi, and local-bin are live-home dependencies; changing XDG directories does not isolate them. | `fish/config.fish:20-38,77-131,166-176`; `fish/conf.d/rustup.fish:1` |
| Runtime writes | `z` creates `Z_DATA` and `sponge` sets universal variables; a preview must isolate both before it starts. | `fish/conf.d/z.fish:1-15`; `fish/conf.d/sponge.fish:5-31` |
| Live-only secrets overlay | `fish/conf.d/secrets.local.fish` exists in live only, is git-ignored, and every `conf.d` load sources it. It survives promotion (verified: `git restore` deletes tracked files and leaves untracked ones). Never copy it into the workshop or read its values. | `.gitignore:227-228`; `fish/conf.d/secrets.local.fish:1` |
| Generated/local state | `fish_variables` is ignored runtime state; `completions/copilot.fish` is untracked generated output; `.DS_Store` files are ignored metadata. | `.gitignore:14,232`; `fish/fish_variables:1-14`; `fish/completions/copilot.fish:1-2` |

---

## 🅿 PARKED — real, but not the Whale. Do not start from here.

- tmux: review latest `tmux-loop-rescue` delta (SHA `94daaa4f…`)
- tmux: durability decision for incident evidence (private archive vs separate repo)
- tmux: file the Sep 9 crash upstream (draft exists)
- tmux: optional per-project servers, `history-limit` trial, `tincident` starter
- Private follow-ups tracked outside this public repo
- Vivaldi fresh profile (outside `~/.config`)

---

## 📜 LOG

| Date       | Lane | Entry                                                                                                                                                                          |
| ---------- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-15 | 0    | Tag + `~/.config-next` worktree created                                                                                                                                        |
| 2026-09-15 | —    | CC roadmap canonical, Codex principle layered; tracker created                                                                                                                 |
| 2026-09-15 | —    | Codex review: bounded promotion sets, retirement-candidate inventory, Ghostty version-specific preview preflight, no-force promotion, and Neovim archive protection clarified  |
| 2026-09-15 | —    | Tracker committed on `rebuild/dotfiles` as the first checkpoint                                                                                                                 |
| 2026-09-15 | 0.5  | Angel adopted Codex's order: read-only fish contract audit first, fish core at lane 6, each tool's fish glue moves with its lane; lane 0.5 started                              |
| 2026-09-15 | 0.5  | Codex completed static Fish contract: startup, lane ownership, callers, preview leaks, and runtime-data boundaries mapped                                                       |
| 2026-09-15 | 0    | **Blank slate.** Angel nuked the workshop: 415 files deleted, only WHALE.md remains. Nothing is ported; the audit became the BREAK LIST; museum access via the baseline tag     |
