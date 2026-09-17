# 🐋 WHALE — dotfiles rebuild tracker

The single source of truth. If it is not in this file, it is not happening.

**Blank slate.** The workshop is empty. Nothing is ported. Anything that comes back is typed from scratch, because Angel missed it. What never comes back was never important.

The old tree is a museum: read it, never copy it. Live `~/.config` keeps running until a lane is promoted.

---

## ▶ NOW

| Field       | Value                                                                    |
| ----------- | ------------------------------------------------------------------------ |
| Lane        | 1 · Ghostty                                                              |
| Status      | ⏸ waiting on Angel                                                      |
| Next action | Angel says what a fresh Ghostty should feel like; then preview preflight |
| Blocked by  | Angel                                                                    |

---

## 📋 QUEUE — first to last

| #   | Lane                     | Built from scratch in `~/.config-next`                  | Status | Done looks like                                                          |
| --- | ------------------------ | ------------------------------------------------------- | ------ | ------------------------------------------------------------------------ |
| 0   | Foundation               | tag + worktree + empty workshop                         | ✅     | tag `dotfiles-before-redesign-2026-09-15`; workshop holds only this file |
| 0.5 | 🐟 Fish break list       | read-only audit of what calls into fish                 | ✅     | BREAK LIST below: what dies the moment fish is empty                     |
| 1   | Ghostty                  | `ghostty/`                                              | ⏸     | _Angel defines_                                                          |
| 2   | Alacritty decision       | `alacritty/`                                            | ⏳     | rebuilt from zero, or left dead                                          |
| 3   | Starship                 | `starship/`                                             | ⏳     | _Angel defines_                                                          |
| 4   | Yazi                     | `yazi/` + its fish entry points                         | ⏳     | _Angel defines_                                                          |
| 5   | eza + git                | `eza/` `git/` + its fish entry points                   | ⏳     | _Angel defines_                                                          |
| 6   | 🐟 Fish core             | `fish/` minus what other lanes claim                    | ⏳     | _Angel defines_                                                          |
| 7   | tmux                     | `tmux.conf` from zero; `tmux/tools/` survives untouched | ⏳     | _Angel defines_                                                          |
| 8   | Hammerspoon              | `hammerspoon/`                                          | ⏳     | _Angel defines_                                                          |
| 9   | yabai + skhd + Karabiner | `yabai/` `skhd/` `karabiner/` + their fish entry points | ⏳     | _Angel defines_                                                          |
| 10  | Root sweep               | repo root and docs                                      | ⏳     | root holds only what belongs; README/CLAUDE.md describe the new house    |
| 11  | 🐋 Neovim                | `nvim/` + its fish entry points                         | 🔒     | separate 2026–27 project; locked until then                              |

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

| Need                    | Command                                                                       |
| ----------------------- | ----------------------------------------------------------------------------- |
| List the old files      | `git -C ~/.config ls-tree -r --name-only dotfiles-before-redesign-2026-09-15` |
| Read one old file       | `git -C ~/.config show dotfiles-before-redesign-2026-09-15:ghostty/config`    |
| See a setting's history | `git -C ~/.config log -p --all -- <path>`                                     |
| The live copy           | still running in `~/.config` until that lane is promoted                      |

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

| Order | Contract                                                                                                                                                                                | Evidence                                                                                                                                        |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| 0     | Fish runtime handling of universal variables and `conf.d` precedes this file only by Fish semantics; exact order is **UNVERIFIED** because this audit did not start Fish.               | `fish/fish_variables:1-14`; `fish/conf.d/fzf.fish:1-14`; `fish/conf.d/rustup.fish:1`; `fish/conf.d/sponge.fish:1-52`; `fish/conf.d/z.fish:1-46` |
| 1     | Global startup exports `STARSHIP_CONFIG`, `EZA_CONFIG_DIR`, `PYENV_ROOT`, `BASH_ENV`, `EDITOR`, and `VISUAL`; Homebrew and pyenv mutate `PATH`.                                         | `fish/config.fish:4-42`                                                                                                                         |
| 2     | `config.fish` prepends every `internal/*/` directory to `fish_function_path`, then eagerly sources the Codex wrapper.                                                                   | `fish/config.fish:50-65`                                                                                                                        |
| 3     | Interactive shells initialize Starship, source the Gruvbox theme, lazily integrate jenv, initialize fnm, hook direnv, define eza aliases/abbrs/binding, and keep `n`/`nvim-v3` aliases. | `fish/config.fish:68-159`                                                                                                                       |
| 4     | All shells add Kimi and local-bin paths after the interactive block. `fish_plugins` is a Fisher manifest, not a startup install command.                                                | `fish/config.fish:166-180`; `fish/fish_plugins:1-4`; `fish/functions/fisher.fish:1`                                                             |

### Per-lane break contract

| Lane                       | Fish surface and entry points                                                                                                      | Must keep working, or die on purpose                                                                           | Evidence                                                                                                                                                                      |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 Ghostty                  | No Fish-owned file. Ghostty detects shell integration but does not statically select Fish.                                         | `SHELL`/login-shell route **UNKNOWN**; a new Ghostty terminal must reach the expected interactive Fish prompt. | `ghostty/config:90-99`                                                                                                                                                        |
| 2 Alacritty                | Alacritty directly starts Fish.                                                                                                    | `/opt/homebrew/bin/fish` remains executable; a new Alacritty window starts cleanly.                            | `alacritty/alacritty.toml:104-105`                                                                                                                                            |
| 3 Starship                 | Fish exports `STARSHIP_CONFIG` and pipes `starship init fish` into `source`.                                                       | `STARSHIP_CONFIG`; interactive prompt and theme render.                                                        | `fish/config.fish:4,68-75`                                                                                                                                                    |
| 4 Yazi                     | `yazi` preserves cwd through a temp file; `lf` starts Neovim's current rebuild with Yazi.                                          | `NVIM_APPNAME`; `yazi` returns to selected cwd and `lf` opens the expected editor route.                       | `fish/functions/yazi.fish:2-12`; `fish/internal/yazi/lf.fish:2-4`                                                                                                             |
| 5 eza + git                | eza aliases are `ls la ll ld lr lt`; `set-eza-theme` reads and writes the eza theme link. No Git-owned Fish entry point was found. | `EZA_CONFIG_DIR`; aliases and selector work; Git-oriented fzf helpers remain available.                        | `fish/config.fish:5,140-147`; `fish/internal/eza/set-eza-theme.fish:1-22`; `fish/functions/_fzf_search_git_status.fish:1`                                                     |
| 6 Fish core                | Owns everything below not claimed by another lane; detailed ledger follows.                                                        | Preserve noninteractive and interactive startup.                                                               | `fish/config.fish:4-180`                                                                                                                                                      |
| 7 tmux                     | `t`, `tn`, `tK`, `tai`, `tfreeze`, `trescue`; `tai` launches a login Fish in new agent panes.                                      | `TMUX`, `TMUX_FREEZE_CAPTURE_*`, `TMUX_SHORTCUTS_LAB_*`; emergency safeguards remain intact.                   | `fish/internal/tmux/t.fish:1-8`; `fish/internal/tmux/tai.fish:86-109`; `fish/internal/tmux/tfreeze.fish:1-69`; `fish/internal/tmux/trescue.fish:1-75`                         |
| 8 Hammerspoon              | No Fish-owned surface or static direct caller found.                                                                               | Runtime coupling **UNKNOWN**; do not infer a safe change from static absence.                                  | `UNKNOWN (static scan: hammerspoon/)`                                                                                                                                         |
| 9 yabai + skhd + Karabiner | `ys yk yp yr _swap_skhd_profile sk skr`; skhd invokes `fish -c` for `yr` and `yp`.                                                 | `HOME`, `PATH`; service and profile hotkeys still resolve Fish and their functions.                            | `fish/internal/yabai/yp.fish:13-62`; `fish/internal/yabai/yr.fish:13-111`; `fish/internal/skhd/sk.fish:3-10`; `skhd/skhdrc:45-67`; `skhd/modules/shared/services.skhdrc:6-25` |
| 10 Root sweep              | No Fish surface is owned; docs retain a manual source instruction.                                                                 | External callers stay inventory-only.                                                                          | `CLAUDE.md:13,41-45`                                                                                                                                                          |
| 11 Neovim 🔒               | Locked: `v`, `vim`, plus `n` and `nvim-v3` aliases; Neovim itself selects Fish as shell.                                           | `NVIM_APPNAME`; plain `nvim`, `n`, `v`, and `vim` retain their current routes until lane 11.                   | `fish/internal/nvim/v.fish:2-9`; `fish/internal/nvim/vim.fish:2-9`; `fish/config.fish:158-159`; `nvim-rebuild/lua/core/options.lua:75`                                        |

### Lane 6 core ledger

| Area           | Owned contract                                                                                                                                                                                                                                                                                                                                                               | Evidence                                                                                                                                                                                                                                                                                           |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Agent boundary | `_agent_limit` caps child agent trees; wrappers are `claude cc cu agy gemini qwen deepseek openrouter codex kimi kimi-cli`. Preserve `AGENT_NPROC_CAP`. Credential and routing variables are referenced by family only: the DeepSeek and OpenAI provider key variables, the Anthropic variable family, the OpenAI base-URL variable, and the Claude subagent-model variable. | `fish/internal/claude/_agent_limit.fish:31-64`; `fish/internal/claude/claude.fish:8-14`; `fish/internal/claude/cc.fish:2-58`; `fish/internal/claude/deepseek.fish:1-53`; `fish/internal/claude/openrouter.fish:1-101`; `fish/internal/codex/codex.fish:1-48`; `fish/internal/kimi/kimi.fish:34-38` |
| System helpers | `bu`; `net`; Python/pyenv wrappers; `freeport sbr sbt sr st`; `trash-pick`; tracked dormant `vscode/c.txt`; project worktree helpers `cvmapp-wt* cwt rp-wt* rwt stage-wt* swt swt-close`. Home-level tool roots and `PATH` are dependencies.                                                                                                                                 | `fish/internal/brew/bu.fish:1-2`; `fish/internal/net/net.fish:46-52,323,528`; `fish/internal/python/_pyenv_lazy_init.fish:1-4`; `fish/internal/spring-boot/freeport.fish:1-13`; `fish/internal/worktree/stage/stage-wt.fish:1`                                                                     |
| Interactive UX | Fisher-managed `fzf`, `sponge`, and `z` functions/conf.d, generic completions, Gruvbox theme, `..`/`...`, and Ctrl-D binding belong here; `yazi.fish` is lane 4. Variables: `Z_DATA`, `Z_DATA_DIR`, `Z_CMD`, `ZO_CMD`, `Z_EXCLUDE`, `sponge_*`, `fish_key_bindings`.                                                                                                         | `fish/conf.d/fzf.fish:1-21`; `fish/conf.d/sponge.fish:1-52`; `fish/conf.d/z.fish:1-46`; `fish/config.fish:73-75,149-155`; `fish/fish_plugins:1-4`                                                                                                                                                  |

### External caller ledger

| Caller                 | Contract                                                                                                                                                                                                                                               | Evidence                                                                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| Alacritty              | Directly execs Fish, so every Fish startup regression is an Alacritty regression.                                                                                                                                                                      | `alacritty/alacritty.toml:104-105`                                                                                                     |
| skhd                   | Root uses Bash, shared service bindings explicitly run `fish -c "yr"` and `fish -c "yp …"`; changing autoload/path breaks hotkeys.                                                                                                                     | `skhd/skhdrc:45-61`; `skhd/modules/shared/services.skhdrc:6-25`                                                                        |
| Neovim                 | Sets its shell to Fish; shell commands depend on Fish startup.                                                                                                                                                                                         | `nvim-rebuild/lua/core/options.lua:75`                                                                                                 |
| tmux emergency path    | Fish functions call the Fish capture script through absolute tmux-tool paths.                                                                                                                                                                          | `fish/internal/tmux/tfreeze.fish:7-10,62-69`; `fish/internal/tmux/trescue.fish:7-10,64-75`; `tmux/tools/tmux-freeze-capture.fish:1,53` |
| External repair script | `~/.scripts/fix-effort.sh` invokes Fish and mutates live Fish state/source; it is outside this repo but must be inventoried before any variable or path redesign.                                                                                      | `~/.scripts/fix-effort.sh:6,10,14-15,22-23`                                                                                            |
| Scan boundary          | No static direct invocation was found in `hammerspoon/`, `yabai/`, `karabiner/`, `yazi/`, active `tmux/tmux.conf`, `git/`, `~/.local/bin`, LaunchAgents, or current Claude/Codex settings/statusline files; runtime/system callers remain **UNKNOWN**. | `UNKNOWN (static search only)`                                                                                                         |

### Preview hazards and live-only state

| Item                      | Hazard                                                                                                                                                                                                                                                         | Evidence                                                                             |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Live-root leaks           | The old config hardcodes the live Fish internal root, Codex source, theme, Starship, and eza paths; an XDG-only preview would load live behavior. A fresh fish must resolve its own root.                                                                      | `fish/config.fish:4-5,50-65,73-75`                                                   |
| Home-level tools          | pyenv, `BASH_ENV`, jenv, fnm, direnv, Cargo, Kimi, and local-bin are live-home dependencies; changing XDG directories does not isolate them.                                                                                                                   | `fish/config.fish:20-38,77-131,166-176`; `fish/conf.d/rustup.fish:1`                 |
| Runtime writes            | `z` creates `Z_DATA` and `sponge` sets universal variables; a preview must isolate both before it starts.                                                                                                                                                      | `fish/conf.d/z.fish:1-15`; `fish/conf.d/sponge.fish:5-31`                            |
| Live-only secrets overlay | `fish/conf.d/secrets.local.fish` exists in live only, is git-ignored, and every `conf.d` load sources it. It survives promotion (verified: `git restore` deletes tracked files and leaves untracked ones). Never copy it into the workshop or read its values. | `.gitignore:227-228`; `fish/conf.d/secrets.local.fish:1`                             |
| Generated/local state     | `fish_variables` is ignored runtime state; `completions/copilot.fish` is untracked generated output; `.DS_Store` files are ignored metadata.                                                                                                                   | `.gitignore:14,232`; `fish/fish_variables:1-14`; `fish/completions/copilot.fish:1-2` |

---

## 🏠 PART 2 · THE ROOT — designed 2026-09-16, nothing moved

One visible root holds every possession, so one backup covers it. Dotfiles and tool-owned dot-dirs stay at `$HOME`; they are rebuildable and never move.

**Grammar:** `root / <type> / <subject>`. First folder is what kind of thing, second is what it is about. Never the other way round, not even for work. A tmux session is a subject; the types are directories, so `CVMAPP` lands on `repos/cvmapp` and its notes and scripts are one `cd` away.

```
~/desk/                          name retained 2026-09-16
├── notes/<subject>/             everything Angel writes: tool notes, project notes, research, personal
│   └── personal/                journal · learning · career · life admin
├── scripts/<subject>/           Angel's scripts; scripts a config invokes stay next to that config
├── repos/<subject>/             UNDECIDED 2026-09-17: Angel's target tree omits repos; they may stay at ~/.repository, ~/.westernu, ~/.skills
├── playground/<subject>/        the warzone; disposable by contract
├── audits/<subject>/<YYYY-MM-DD>-<kind>/      planned proof: audit rounds, harness runs, model comparisons, tai panels
├── incidents/<subject>/<YYYY-MM-DD>-<kind>/   breakages: freezes, crashes, storms; tools capture straight into it
├── backups/<subject>/           copies of something that lives elsewhere: VPS dumps, git bundles, service exports; never a copy of desk itself
├── idle/<subject>/              stuff Angel does not care about now but might want back; renamed from `archive` 2026-09-17 because a backup has intent and an archive does not
└── family/                      protected media; backup policy, not git
```

**Decided:**

- `audits` and `incidents` are two types (Angel's decision 2026-09-16, after CC briefly merged them into `cases` on an inferred agreement; reverted the same day). Same case skeleton, same lifecycle, different intent: an audit is something Angel set out to prove, an incident is something that happened to him. Eight types total. Today incident material sits in 11 places (~630 MB): the tmux dossier in the public config repo, September audit residue in `$HOME` and `.westernu`, memory backups, six incident write-ups in agent memory. Rules:
- `backups` is a type (Angel, 2026-09-17, after first declining it the same night). Rule: it holds copies of things that live somewhere else, never a copy of anything already in `desk/`; restic to an external drive protects `desk/` itself. Live: `claude/memory-backups`, `config/config-prepurge-backup.git`, `cvmapp/{db,db-archive,pre-edit,branch bundle}`, `google/` Takeout, `stage/stage-pg`, `ublock/`. The cvmapp pull script (`desk/scripts/cvmapp/redhat-vps/cvmapp-pull-backup.sh:10`) writes to `backups/cvmapp/db/`; `db-archive/` must stay a sibling of `db/` because the retention `find` has no `-maxdepth`. Tool-owned auto-backups (`~/.claude/backups`, `karabiner/automatic_backups`, nvim backupdir) stay put.
  - Grammar: `audits/<subject>/<YYYY-MM-DD>-<kind>/` and `incidents/<subject>/<YYYY-MM-DD>-<kind>/`. Subject is whatever broke: `tmux`, `yabai`, `host`, `cvmapp`. No pre-made subject folders; one appears the day it is needed.
  - Every case gets the same skeleton from `<type>/_template/`: `CASE.md`, `timeline.md`, `recovery.md`, `decisions.md`, `evidence/`, `fixes/`. each type's `INDEX.md` lists its cases.
  - Tools capture straight into it: `tfreeze` writes its next capture to `desk/incidents/tmux/<date>-freeze/`, no promotion step.
  - Closed incidents stay put, marked `STATE: CLOSED` in `CASE.md`. This is the one exception to idle-by-move: past incidents are reference, and `ls incidents/tmux/` must always show history.
  - Branch-bound audit outputs and fixes stay in their project worktree when parallel review isolation matters; the case links to the commit or run instead of becoming a second source of truth.
  - Apple's `~/Library/Logs/DiagnosticReports/` is never relocated; the specific report is copied or referenced into the case.
  - The `/review` harness's own output paths are untouched and out of scope; `audits/` and `incidents/` hold only what the harness never owned: tai panels, ad-hoc audits, bug logs, hand-built verifiers, incident dossiers.
  - Kind test for any path: what kind of thing is this? If not a note, it is not under `notes/`. `notes/audits/` and `notes/incidents/` are the mistake this rule exists to prevent.
  - First landing done 2026-09-17: `desk/incidents/tmux/2026-09-13-freeze/`. Capture tools repointed to `desk/incidents/tmux`; memory files updated.
- `research` is not a type; it is notes.
- Personal, no-project material is `notes/personal/`.
- Work is not walled: `cvmapp` is a subject like `stage`; `westernu` appears only when the employer itself is the subject. Liftable later with one `mv desk/*/cvmapp`.
- Inactive things move to `idle/`, they do not get marked in place. (`archive` was renamed to `idle` on 2026-09-17: Angel does not use the word archive; `backups` has a clear intent, `idle` is simply what he is not using.)
- Git only where branches matter: each `repos/<x>` is its own repo. `notes/` has NO git (decided 2026-09-16, CC + Codex + Angel): plain files, write freely, versioned and backed up by restic encrypted snapshots instead. `scripts/` may be a private repo. `family/` and `archive/` are never git.
- Secrets never live in files: every credential value goes to a password manager; a note holds a pointer only. First move of Part 2, before any backup runs: the credential `.md` files currently under `desk/.family/me/vps/` (token, recovery key, ssh) go to the password manager.
- `desk/family/` holds protected media only (yaretzy, dad, mom, anthony). Notes about family are `notes/family/<person>`. The current `desk/.family/me/` is 29 markdown notes misfiled under media; they land in `notes/personal/…`, `notes/vps`, `notes/startup`, `notes/danny`.
- Sequencing rule, non-negotiable: restic running against `desk/`, one snapshot taken, one test note restored, before the `.git` comes out of notes. Never a moment where notes are one copy on one SSD.

**Where today's roots land:**

| Today                                                                                                                                                | Lands in                                                                                             |
| ---------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `~/.notes`                                                                                                                                           | `notes/` (projects split into subjects; personal into `notes/personal/`; `secret/` stays local-only) |
| `~/.scripts`                                                                                                                                         | `scripts/<subject>/`                                                                                 |
| `~/.repository/*`                                                                                                                                    | `repos/<x>`                                                                                          |
| `~/.westernu/cvmapp`, `notes`, audits                                                                                                                | `repos/cvmapp`, `notes/westernu`, `playground/` or `archive/`                                        |
| `~/.skills/review-protocol`                                                                                                                          | `repos/review-protocol`                                                                              |
| `~/.archive`                                                                                                                                         | `idle/`                                                                                              |
| `~/desk/.family`                                                                                                                                     | `family/`                                                                                            |
| `~/desk/playground`                                                                                                                                  | stays                                                                                                |
| `~/.config/tmux/incidents`, `.westernu/audit-*`, `~/.audit-scratch-*`, `.da-r6-audit`, `.r7-audit-scratch`, `.review-catch`, `.cc-review-harness-v2` | `incidents/<subject>/<date>-<kind>/` after a per-case look                                           |
| `~/.config*`, `~/.ssh`, `~/.claude`, every tool dot-dir                                                                                              | stay at `$HOME`                                                                                      |

**Why this exists — the sprawl it kills:** today "where is the note about X" has no answer: `~/.notes/tooling/fish`, `~/.notes/projects/wifi/{reviews,templates,generated,tmp}`, `~/.westernu/notes/{database,infra,deploy,old,scratch}`, 179 `notes` dirs across `$HOME`. After: `desk/notes/<subject>` is the only answer for notes Angel owns personally.

**Ownership rule (learned the hard way with `gwt`):** a project's knowledge lives in `repos/<x>/notes/`, versioned with the code, one copy per worktree, so parallel review rounds never write over each other. That includes human-written plans, decisions, runbooks and onboarding, not just harness receipts; moving them out of the repo separates instructions from the version they describe. Two lines, both true:

```
repos/<x>/notes/     anything that can go stale against a commit: plans, review rounds, decisions in flight, runbooks tied to a version
desk/notes/<x>/      anything that must survive the repo: notes for a public repo (config), post-mortems, the layer you would want if the project were deleted tomorrow
```

For a heavy harness project like stage the second line may stay empty. For config it is the only line, because the repo is public.

**tmux is the front door.** Every day starts: boot → Ghostty → tmux → pick a session. Sessions are subjects, except that one session can span several: `config` covers fish, tmux, ghostty, starship. The tree does not bend for that, no `notes/config/`; the launcher carries a small session → subjects map (`CVMAPP → cvmapp`, `config → fish tmux ghostty …`). The tree must make `session → desk/*/<subject>` trivial; a session launcher is lane 7 work, carried here so Part 2 never designs against it.

**Before a single move:**

1. Path-binding map: 37 memory dirs keyed by absolute path, 39 worktree gitdir pointers, 50 tmux-resurrect saves, fish functions, symlinks, agent configs, launchd, Obsidian vault registration. Each with its repair command.
2. Backup tool chosen and running against the root: restic or Time Machine to an external disk. Not iCloud; it rewrites `.git` and symlinks and is sync, not backup.
3. Then one move sitting, one repair, verify, done. No symlink bridges.

Sequenced after Part 1 lanes unless Angel reorders.

## 🅿 PARKED — real, but not the Whale. Do not start from here.

- tmux: review latest `tmux-loop-rescue` delta (SHA `94daaa4f…`)
- tmux: durability decision for incident evidence (private archive vs separate repo)
- tmux: file the Sep 9 crash upstream (draft exists)
- tmux: optional per-project servers, `history-limit` trial, `tincident` starter
- Private follow-ups tracked outside this public repo
- Vivaldi fresh profile (outside `~/.config`)

---

## 📜 LOG

| Date       | Lane | Entry                                                                                                                                                                                                                                                                                              |
| ---------- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-15 | 0    | Tag + `~/.config-next` worktree created                                                                                                                                                                                                                                                            |
| 2026-09-15 | —    | CC roadmap canonical, Codex principle layered; tracker created                                                                                                                                                                                                                                     |
| 2026-09-15 | —    | Codex review: bounded promotion sets, retirement-candidate inventory, Ghostty version-specific preview preflight, no-force promotion, and Neovim archive protection clarified                                                                                                                      |
| 2026-09-15 | —    | Tracker committed on `rebuild/dotfiles` as the first checkpoint                                                                                                                                                                                                                                    |
| 2026-09-15 | 0.5  | Angel adopted Codex's order: read-only fish contract audit first, fish core at lane 6, each tool's fish glue moves with its lane; lane 0.5 started                                                                                                                                                 |
| 2026-09-15 | 0.5  | Codex completed static Fish contract: startup, lane ownership, callers, preview leaks, and runtime-data boundaries mapped                                                                                                                                                                          |
| 2026-09-15 | 0    | **Blank slate.** Angel nuked the workshop: 415 files deleted, only WHALE.md remains. Nothing is ported; the audit became the BREAK LIST; museum access via the baseline tag                                                                                                                        |
| 2026-09-16 | —    | $HOME cleanup (separate from lanes): .NET retired, 25 dead caches trashed, ~/.hammerspoon retired via MJConfigFile; 98 → 74 entries. Reports in ~/.notes/tmp/config-next-2026-09-16                                                                                                                |
| 2026-09-16 | P2   | PART 2 designed with Codex: one root, type/subject grammar, research folded into notes, work unwalled, archive by move. Nothing moved                                                                                                                                                              |
| 2026-09-16 | P2   | Decided: notes/ without git, restic snapshots instead; secrets to a password manager first; family/ is media only; desk name retained                                                                                                                                                              |
| 2026-09-16 | P2   | `incidents` added as the seventh type: one home for every breakage, tools capture straight in, closed cases stay put; tmux dossier is the first landing                                                                                                                                            |
| 2026-09-16 | P2   | `incidents` + `audits` briefly merged into `cases` on CC's inference; Angel reverted to two types the same day. Five audit dirs out of `$HOME` into `desk/audits/`; harness paths off limits                                                                                                       |
| 2026-09-17 | P2   | tmux freeze dossier moved to `desk/incidents/tmux/2026-09-13-freeze/` (27,991 files manifest-verified); capture tools default to `desk/incidents/tmux`; four more audits from playground into `desk/audits/`                                                                                       |
| 2026-09-17 | P2   | `backups` added as a type; six scattered backups (Takeout, pre-purge config, stage-pg, cvmapp bundle, uBlock, memory snapshot) and `~/cvmapp-backups` moved into `desk/backups/`; first VPN pull into the new path verified by CC and Codex; capture-path edits committed on development (53442ee) |
