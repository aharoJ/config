Let me research the current state of Git plugins for Neovim to give you the most up-to-date landscape.Alright, here's the full landscape broken down through the lens of your constitution and workflow.

---

## The Git Plugin Landscape for Neovim (Feb 2026)

There are really **three layers** of git integration to think about, and your tmux-first architecture already answers one of them:

### Layer 1: Buffer-level git awareness (signs, hunks, blame)

**gitsigns.nvim** — by lewis6991. This is the undisputed king and effectively the only serious option. 6,400+ stars, actively maintained (last sync Feb 9, 2026), pure Lua, async via luv. It does one thing extremely well: deep buffer integration for git.

What it gives you: sign column indicators for added/changed/deleted lines, hunk navigation (`]c`/`[c` or `]h`/`[h`), stage/unstage/reset individual hunks (including partial hunks in visual mode), inline blame, diff against index or any revision, word-level diff, hunk text object (`ih`), and status variables your lualine can consume (`b:gitsigns_head`, `b:gitsigns_status_dict`).

The modern API uses `nav_hunk("next"/"prev"/"first"/"last")` instead of the older `next_hunk()`/`prev_hunk()`. The `on_attach` callback is the correct place for buffer-local keymaps. No plenary dependency needed anymore (it was dropped). Zero config is valid — `require("gitsigns").setup()` with no args gives you sensible defaults.

**Verdict: Must-have. This is your `plugins/tools/git.lua`.**

### Layer 2: Full git UI (staging, committing, rebasing, log browsing)

This is where it gets interesting, and where your tmux philosophy matters most. There are three schools:

**Option A: lazygit in a tmux pane** — This is the most aligned with your constitution. lazygit is a standalone TUI (Go-based, ~50k stars), and since you already have tmux as your persistent terminal layer, you just pop it open in a tmux pane or window. No Neovim plugin needed at all. `<C-Space>` → new pane → `lazygit` → done. This is what ThePrimeagen and many tmux-native workflows use. There IS a `lazygit.nvim` plugin (kdheepak, 2.1k stars) but it essentially just opens a floating terminal inside Neovim — which violates your Rule 7 ("Neovim Is Not A Terminal Multiplexer"). If you're running tmux, the plugin is redundant.

**My recommendation for your philosophy: lazygit in tmux (no Neovim plugin). Skip fugitive, skip neogit.** You already declared tmux as the session/terminal layer. lazygit is a first-class terminal app — it doesn't need to be embedded in Neovim. This keeps your Neovim plugin count down and respects the spatial architecture.

### Layer 3: Diff viewing (multi-file diffs, file history, merge conflict resolution)

**diffview.nvim** — by sindrets (5.2k stars, last activity 5 days ago). This is the one plugin that does something lazygit and gitsigns genuinely can't do as well: a proper tabpage-based diff interface inside Neovim. `:DiffviewOpen` shows all modified files with side-by-side diffs. `:DiffviewFileHistory` traces commit history for a file or the whole repo. Excellent for merge conflict resolution with 3-way diffs.

The question is whether you _need_ this. If your merge conflict workflow is already handled by lazygit (which has its own conflict resolution UI) or by the raw `nvim -d` diff mode, you can skip it. But if you do code review or complex merges frequently, diffview is genuinely excellent and nothing else replicates it.

**Verdict: Optional but worth considering later. Not essential for Phase 2.**

### Other notable mentions (and why to skip them)

| Plugin              | What                        | Why Skip                                          |
| ------------------- | --------------------------- | ------------------------------------------------- |
| `git-conflict.nvim` | Merge conflict markers      | gitsigns + diffview cover this                    |
| `git-blame.nvim`    | Dedicated blame plugin      | gitsigns has `current_line_blame` built in        |
| `gitlinker.nvim`    | Copy GitHub permalinks      | Nice-to-have, not essential. Can be a shell alias |
| `octo.nvim`         | GitHub PR reviews in Neovim | Very specialized, use GitHub web or `gh` CLI      |

---
