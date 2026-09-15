# 🐋 WHALE — dotfiles redesign tracker

The single source of truth. If it is not in this file, it is not happening.
Work top to bottom. One lane at a time. Nothing moves without Angel's greenlight.

---

## ▶ NOW

| Field       | Value                                                      |
| ----------- | ---------------------------------------------------------- |
| Lane        | 1 · Ghostty                                                |
| Status      | ⏸ awaiting greenlight                                      |
| Next action | Preflight: find a side-by-side preview that works on 1.3.1 |
| Blocked by  | Angel's greenlight                                         |

---

## 📋 QUEUE — first to last

| #   | Lane                     | Folder(s)                                  | Status | Done looks like                                                                                    |
| --- | ------------------------ | ------------------------------------------ | ------ | -------------------------------------------------------------------------------------------------- |
| 0   | Foundation               | tag + `~/.config-next`                     | ✅     | tag `dotfiles-before-redesign-2026-09-15`, worktree on `rebuild/dotfiles`                          |
| 1   | Ghostty                  | `ghostty/`                                 | ⏸      | _Angel defines_                                                                                    |
| 2   | Alacritty decision       | `alacritty/`                               | ⏳     | keep or retire, decided once                                                                       |
| 3   | Starship                 | `starship/`                                | ⏳     | _Angel defines_                                                                                    |
| 4   | Yazi                     | `yazi/`                                    | ⏳     | _Angel defines_                                                                                    |
| 5   | eza + git                | `eza/` `git/`                              | ⏳     | _Angel defines_                                                                                    |
| 6   | fish                     | `fish/`                                    | ⏳     | _Angel defines_                                                                                    |
| 7   | tmux                     | `tmux/` (config + tools only)              | ⏳     | _Angel defines_                                                                                    |
| 8   | Hammerspoon              | `hammerspoon/`                             | ⏳     | _Angel defines_                                                                                    |
| 9   | yabai + skhd + Karabiner | `yabai/` `skhd/` `karabiner/`              | ⏳     | _Angel defines_                                                                                    |
| 10  | Root sweep               | repo root, `cagent/`, docs                 | ⏳     | root holds only what belongs; README/CLAUDE.md match reality; no Neovim-related archive is touched |
| 11  | 🐋 Neovim                | `nvim/` `nvim-rebuild/` `nvim-v3/` `.bak/` | 🔒     | separate 2026–27 project; do not touch before then                                                 |

Status: ✅ done · ▶ in progress · ⏸ waiting on Angel · ⏳ queued · 🔒 locked

---

## 🛡 GUARDRAILS

1. One lane, one bounded promotion set, one preview, one promotion commit, one easy revert.
2. Live `~/.config` changes only by promotion, only after Angel approves.
3. No lane starts until the one above it is ✅ or Angel reorders this file.
4. Something new comes up → it goes into PARKED. It does not start.
5. Clutter is a retirement candidate, never an assumed deletion. Inventory it per lane before touching it; never blanket-delete `*.bak`, `.bak/`, or `backup/`.
   Git only protects tracked files; untracked or ignored files are archived first or left alone.
6. Before promotion, verify the live target has no unreviewed modification or untracked runtime data that the promotion could overwrite. Never force a promotion.
7. tmux incident fixes, tools, and `tmux/incidents/` stay intact and private.
8. Public repo: no secrets, no private evidence.
9. Minimal comments. Keep the existing header annotation convention.
10. Neovim stays locked until lane 11; Root Sweep must not retire its `.bak/` material, source, or runtime data.

---

## 🔁 LANE LOOP — copy into the lane's section when it starts

- [ ] Contract: done looks like · smoke test · rollback
- [ ] Inventory the declared lane surface: hardcoded `.config/` paths, dependents, clutter (tracked / untracked / generated), and runtime data outside Git
- [ ] Preview method proven for the installed app version before any redesign
- [ ] Build only within the lane's declared surface in `~/.config-next`
- [ ] Side-by-side preview
- [ ] Smoke test on real work
- [ ] Commit on `rebuild/dotfiles`
- [ ] Angel approves promotion
- [ ] Verify the live target and staged promotion set contain only the intended lane; no force or unmanaged-data overwrite
- [ ] `git -C ~/.config restore --source rebuild/dotfiles --staged --worktree -- <tool>/`
- [ ] Review `git -C ~/.config diff --staged` · commit on `development` with a CHANGELOG entry · reload the app
- [ ] Live with it · keep or `git revert`
- [ ] `git -C ~/.config-next rebase development`
- [ ] Mark ✅ here, add a LOG line, move NOW to the next lane

---

## 🎯 ACTIVE LANE

### Lane 1 · Ghostty

- [ ] Contract
  - Done looks like:
  - Smoke test:
  - Rollback: `git revert <promotion commit>`; Ghostty reloads on save
- [ ] Inventory: `ghostty/config` (224 lines), `config.bak`, `config.bak.2`; classify each backup as tracked, untracked, or generated before any retirement decision
- [ ] Preview preflight — `+show-config --config-default-files=false --config-file=…` returned rc=1 on 1.3.1
- [ ] Build
- [ ] Preview
- [ ] Smoke test
- [ ] Commit on `rebuild/dotfiles`
- [ ] Promote `ghostty/` (after approval)
- [ ] Retire verified-dead `config.bak*`
- [ ] Rebase `~/.config-next`

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

| Date       | Lane | Entry                                                                                                                                                                         |
| ---------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-15 | 0    | Tag + `~/.config-next` worktree created                                                                                                                                       |
| 2026-09-15 | —    | CC roadmap canonical, Codex principle layered; tracker created                                                                                                                |
| 2026-09-15 | —    | Codex review: bounded promotion sets, retirement-candidate inventory, Ghostty version-specific preview preflight, no-force promotion, and Neovim archive protection clarified |
| 2026-09-15 | —    | Tracker committed on `rebuild/dotfiles` as the first checkpoint                                                                                                                 |
