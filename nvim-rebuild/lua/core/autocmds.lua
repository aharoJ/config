-- path: nvim/lua/core/autocmds.lua
-- Description: All autocommands and augroups. No plugin config. No keymaps.
-- CHANGELOG: 2026-02-03 | Full rewrite: added terminal, close-with-q, desc on all | ROLLBACK: Replace with previous autocmds.lua
-- CHANGELOG: 2026-02-03 | Added checktime on focus, auto-mkdir on save | ROLLBACK: Remove UserExternalCheck and UserAutoMkdir augroups
-- CHANGELOG: 2026-02-09 | Fixed UserAutoMkdir (was duplicate whitespace trim with wrong group), upgraded trim to winsaveview | ROLLBACK: Revert to previous autocmds.lua

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ── Highlight on Yank ───────────────────────────────────────
-- WHY: Visual feedback when yanking. Near-universal standard.
augroup("UserYankHighlight", { clear = true })
autocmd("TextYankPost", {
	group = "UserYankHighlight",
	callback = function()
		vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
	end,
	desc = "Brief highlight on yank for visual feedback",
})

-- ── Remove Trailing Whitespace on Save ──────────────────────
-- WHY: Clean diffs. No noise in git blame. Professional habit.
-- NOTE: winsaveview/winrestview preserves cursor, scroll position, AND fold state.
augroup("UserTrimWhitespace", { clear = true })
autocmd("BufWritePre", {
	group = "UserTrimWhitespace",
	pattern = "*",
	callback = function()
		local view = vim.fn.winsaveview()
		vim.cmd([[%s/\s\+$//e]])
		vim.fn.winrestview(view)
	end,
	desc = "Remove trailing whitespace on save (preserves cursor + scroll state)",
})

-- ── Return to Last Edit Position ────────────────────────────
-- WHY: When reopening a file, you want to be where you left off, not line 1.
augroup("UserLastPosition", { clear = true })
autocmd("BufReadPost", {
	group = "UserLastPosition",
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local line_count = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= line_count then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
	desc = "Return to last edit position when opening file",
})

-- ── Detect External File Changes ────────────────────────────
-- WHY: If you switch branches in another tmux pane, or another tool edits a file,
-- Neovim should notice and reload. Without this you'd be editing a stale buffer.
augroup("UserExternalCheck", { clear = true })
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
	group = "UserExternalCheck",
	callback = function()
		if vim.o.buftype == "" then
			vim.cmd("checktime")
		end
	end,
	desc = "Check for external file changes on focus/terminal return",
})

-- ── Auto-Create Parent Directories on Save ──────────────────
-- WHY: `nvim some/new/deep/path/file.lua` should just work on :w.
-- Without this, you'd get E212 "Can't open file for writing" if dirs don't exist.
augroup("UserAutoMkdir", { clear = true })
autocmd("BufWritePre", {
	group = "UserAutoMkdir",
	callback = function(args)
		local dir = vim.fn.fnamemodify(args.match, ":p:h")
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, "p")
		end
	end,
	desc = "Create parent directories automatically on save",
})

-- ── Auto-Resize Splits on Terminal Resize ───────────────────
-- WHY: When the terminal window resizes, splits should rebalance automatically.
augroup("UserAutoResize", { clear = true })
autocmd("VimResized", {
	group = "UserAutoResize",
	command = "wincmd =",
	desc = "Auto-resize splits when terminal is resized",
})

-- ── Terminal Buffer Configuration ───────────────────────────
-- WHY: Terminal buffers shouldn't have line numbers or signcolumn.
-- NOTE: For persistent terminals, prefer tmux panes. This is for :terminal one-offs.
augroup("UserTermConfig", { clear = true })
autocmd("TermOpen", {
	group = "UserTermConfig",
	pattern = "*",
	callback = function()
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = "no"
		vim.cmd.startinsert()
	end,
	desc = "Configure terminal buffers: no line numbers, start in insert",
})

-- ── Filetype-Specific Indentation ───────────────────────────
-- WHY: Default is 2-space (covers JS/TS/Java/Lua/YAML/HTML/CSS).
-- Only override for languages where 4-space is the established convention.
augroup("UserIndentOverrides", { clear = true })

autocmd("FileType", {
	group = "UserIndentOverrides",
	pattern = { "python" },
	callback = function()
		vim.opt_local.shiftwidth = 4
		vim.opt_local.tabstop = 4
		vim.opt_local.softtabstop = 4
	end,
	desc = "4-space indent for Python/Rust/C/C++/C#",
})

-- Go uses tabs (not spaces) — convention enforced by gofmt
autocmd("FileType", {
	group = "UserIndentOverrides",
	pattern = "go",
	callback = function()
		vim.opt_local.expandtab = false
		vim.opt_local.shiftwidth = 4
		vim.opt_local.tabstop = 4
		vim.opt_local.softtabstop = 4
	end,
	desc = "Go uses real tabs (gofmt convention)",
})

-- ── Close Certain Filetypes with q ──────────────────────────
-- WHY: Help, quickfix, man pages should close with a single q keystroke.
augroup("UserCloseWithQ", { clear = true })
autocmd("FileType", {
	group = "UserCloseWithQ",
	pattern = { "help", "qf", "man", "lspinfo", "checkhealth" },
	callback = function(event)
		vim.bo[event.buf].buflisted = false
		vim.keymap.set("n", "q", "<cmd>close<CR>", {
			buffer = event.buf,
			silent = true,
			desc = "Close this window",
		})
	end,
	desc = "Close help/qf/man windows with q",
})
