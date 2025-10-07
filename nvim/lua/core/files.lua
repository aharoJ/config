---@diagnostic disable: param-type-mismatch
-- path: lua/core/files.lua
local M = {}

local function ensure_dir(dir)
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
end

function M.setup(cfg)
	cfg = cfg or {}
	local AUTOSAVE = cfg.autosave == true
	local AUTOSAVE_EVENTS = cfg.autosave_events or { "FocusLost", "BufLeave", "WinLeave" }

	-- ── State paths ──────────────────────────────────────────────
	local state_dir = vim.fn.stdpath("state")
	local undo_dir = state_dir .. "/undo"
	local swap_dir = state_dir .. "/swap"
	local backup_dir = state_dir .. "/backup"
	local view_dir = state_dir .. "/view"

	ensure_dir(undo_dir)
	ensure_dir(swap_dir)
	ensure_dir(backup_dir)
	ensure_dir(view_dir)

	-- ── Persistent undo ──────────────────────────────────────────
	vim.opt.undofile = true
	vim.opt.undodir = undo_dir
	vim.opt.undolevels = 10000
	vim.opt.undoreload = 10000

	-- ── Crash/OS safety ──────────────────────────────────────────
	vim.opt.swapfile = true
	vim.opt.directory = swap_dir .. "//"
	vim.opt.backup = true
	vim.opt.writebackup = true
	vim.opt.backupdir = backup_dir
	vim.opt.backupcopy = "auto"
	vim.opt.backupext = ".backup"

	-- ── Encoding & EOL ───────────────────────────────────────────
	vim.opt.encoding = "utf-8"
	vim.opt.fileencoding = "utf-8"
	vim.opt.fileformats = { "unix", "mac", "dos" }

	-- ── Workflow niceties ────────────────────────────────────────
	vim.opt.hidden = true
	vim.opt.confirm = true
	vim.opt.autoread = true
	vim.opt.updatetime = 3000
	vim.opt.updatecount = 200
	vim.opt.shada = { "'1000", "<100", "s20", "h" }
	vim.opt.viewoptions = "folds,cursor,curdir,slash,unix"

	-- ── Autocommands ─────────────────────────────────────────────
	local augroup = vim.api.nvim_create_augroup("core.files", { clear = true })

	-- External file check
	vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
		group = augroup,
		callback = function()
			if vim.o.buftype == "" then
				pcall(vim.cmd, "checktime")
			end
		end,
	})

	-- Restore last cursor pos + folds
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = augroup,
		callback = function(args)
			if vim.bo[args.buf].filetype:match("^git") then
				return
			end
			local mark = vim.fn.line([['"]])
			local last = vim.fn.line("$")
			if mark > 1 and mark <= last then
				pcall(vim.cmd, 'silent! normal! g`"')
				pcall(vim.cmd, "silent! normal! zv")
			end
		end,
	})

	-- Save/load per-file view
	vim.api.nvim_create_autocmd("BufWinLeave", {
		group = augroup,
		callback = function(args)
			if vim.bo[args.buf].buftype == "" and vim.fn.filereadable(args.file) == 1 then
				ensure_dir(view_dir)
				pcall(vim.cmd, "silent! mkview")
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = augroup,
		callback = function(args)
			if vim.bo[args.buf].buftype == "" and vim.fn.filereadable(args.file) == 1 then
				pcall(vim.cmd, "silent! loadview")
			end
		end,
	})

	-- Re-ensure dirs on startup
	vim.api.nvim_create_autocmd("VimEnter", {
		group = augroup,
		callback = function()
			ensure_dir(undo_dir)
			ensure_dir(swap_dir)
			ensure_dir(backup_dir)
			ensure_dir(view_dir)
		end,
	})

	-- Auto-create dirs before writing new files
	vim.api.nvim_create_autocmd("BufWritePre", {
		group = augroup,
		callback = function(a)
			local dir = vim.fn.fnamemodify(a.match, ":p:h")
			if vim.fn.isdirectory(dir) == 0 then
				vim.fn.mkdir(dir, "p")
			end
		end,
	})

	-- Optional autosave
	if AUTOSAVE then
		vim.api.nvim_create_autocmd(AUTOSAVE_EVENTS, {
			group = augroup,
			callback = function()
				if vim.bo.modified and vim.bo.buftype == "" and vim.fn.getcmdwintype() == "" then
					pcall(vim.cmd, "silent! write")
				end
			end,
			desc = "Autosave (safe events only)",
		})
	end

	-- ── Mac-style Undo/Redo ───────────────────────────────────────
	vim.keymap.set({ "n", "x" }, "<M-z>", "<Cmd>undo<CR>", { desc = "Undo (Alt+Z fallback)", silent = true })
	vim.keymap.set({ "n", "x" }, "<M-S-z>", "<Cmd>redo<CR>", { desc = "Redo (Alt+Shift+Z fallback)", silent = true })
	vim.keymap.set("i", "<M-z>", "<C-o>u", { desc = "Undo (Alt+Z fallback)", silent = true })
	vim.keymap.set("i", "<M-S-z>", "<C-o><C-r>", { desc = "Redo (Alt+Shift+Z fallback)", silent = true })

	-- Linux/Windows fallbacks
	if vim.fn.has("mac") == 0 then
		vim.keymap.set({ "n", "x" }, "<C-z>", "u", { desc = "Undo (Ctrl+Z)", silent = true })
		vim.keymap.set({ "n", "x" }, "<C-y>", "<C-r>", { desc = "Redo (Ctrl+Y)", silent = true })
		vim.keymap.set("i", "<C-z>", "<C-o>u", { desc = "Undo (Ctrl+Z)", silent = true })
		vim.keymap.set("i", "<C-y>", "<C-o><C-r>", { desc = "Redo (Ctrl+Y)", silent = true })
	end
end

return M
