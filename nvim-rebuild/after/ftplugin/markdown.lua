-- path: nvim/after/ftplugin/markdown.lua
-- Description: Markdown-specific buffer settings. Soft wrap for prose readability,
--              visual-line navigation so j/k follow wrapped lines, not real lines.
--              Global wrap is OFF (options.lua: vim.opt.wrap = false). This overrides
--              locally for markdown only via vim.opt_local.
--
--              GUARD: Skips floating windows (LSP hover docs have ft=markdown,
--              which triggers this file on every K press in any buffer).
--
-- CHANGELOG: 2026-03-03 | Created. Soft wrap + linebreak + breakindent + gj/gk remaps.
--            | ROLLBACK: Delete this file. No other files reference it.

-- ── Floating Window Guard ─────────────────────────────────────────────
-- WHY: LSP hover windows (K) render as ft=markdown buffers. Without this
-- guard, every hover popup in every filetype would get wrap/linebreak/
-- keymaps applied to its ephemeral buffer. nvim_win_get_config().relative
-- is "" for normal windows and non-empty ("editor", "win", "cursor")
-- for floating windows.
if vim.api.nvim_win_get_config(0).relative ~= "" then
  return
end

-- ── Soft Wrap ─────────────────────────────────────────────────────────
-- WHY wrap: Prose shouldn't scroll horizontally. Long paragraphs should
-- flow visually within the window width without modifying the file.
-- WHY linebreak: Without this, wrap chops mid-word ("architec" / "ture").
-- linebreak breaks only at word boundaries (spaces, hyphens).
-- WHY breakindent: Wrapped continuation lines inherit the indentation
-- level of the original line. Without this, nested list items lose
-- visual hierarchy when they wrap — the continuation snaps to column 0.
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.conceallevel = 2            -- Required for render-markdown.nvim (conceal raw syntax chars)

-- ── Visual Line Navigation ────────────────────────────────────────────
-- WHY: With wrap ON, a single long paragraph is one "real" line that
-- spans multiple screen rows. Default j/k jump by real lines — you'd
-- skip past 5 visible rows in one keystroke. gj/gk move by screen rows.
-- g0/g$ go to the visual beginning/end of the wrapped line.
-- Buffer-local: only affects markdown buffers, code navigation unchanged.
local opts = { buffer = true, silent = true }
vim.keymap.set("n", "j", "gj", opts)
vim.keymap.set("n", "k", "gk", opts)
vim.keymap.set("n", "0", "g0", opts)
vim.keymap.set("n", "$", "g$", opts)


vim.keymap.set("n", "<leader>tw", function()
  vim.opt_local.wrap = not vim.opt_local.wrap:get()
end, { buffer = true, silent = true, desc = "[toggle] wrap" })
