-- core/autocmds.lua
-- Autocommands. Each one does one thing.

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ── Highlight on Yank ──
-- NOTE: vim.highlight was renamed to vim.hl in Neovim 0.11
augroup("YankHighlight", { clear = true })
autocmd("TextYankPost", {
  group = "YankHighlight",
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- ── Filetype Indent Overrides ──
-- Languages where 4-space is standard or readability demands it
augroup("IndentOverrides", { clear = true })
autocmd("FileType", {
  group = "IndentOverrides",
  pattern = { "python", "rust", "go", "java", "kotlin" },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
  end,
})

-- Go uses tabs (not spaces)
autocmd("FileType", {
  group = "IndentOverrides",
  pattern = "go",
  callback = function()
    vim.opt_local.expandtab = false
  end,
})

-- ── Trim Trailing Whitespace on Save ──
augroup("TrimWhitespace", { clear = true })
autocmd("BufWritePre", {
  group = "TrimWhitespace",
  pattern = "*",
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})

-- ── Return to Last Edit Position ──
augroup("LastPosition", { clear = true })
autocmd("BufReadPost", {
  group = "LastPosition",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- ── Auto-resize Splits on Window Resize ──
augroup("AutoResize", { clear = true })
autocmd("VimResized", {
  group = "AutoResize",
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})
