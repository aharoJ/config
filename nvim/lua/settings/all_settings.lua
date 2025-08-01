local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Autosave
local autosave = augroup("autosave", { clear = true })
autocmd({ "FocusLost", "WinLeave" }, {
	group = autosave,
	pattern = "*",
	command = "silent! wa",
})

-- Shada Persistence
local shada = augroup("shada", { clear = true })
autocmd("VimLeave", {
	group = shada,
	pattern = "*",
	command = "wshada!",
})

-- Disable J key
autocmd("FileType", {
	pattern = "*",
	callback = function()
		vim.keymap.set({ "n", "v" }, "J", "<NOP>", { buffer = true })
	end,
})

-- Transparent Backgrounds
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "NONE" })
vim.api.nvim_set_hl(0, "MsgArea", { bg = "NONE" })

-- Line Numbers
vim.api.nvim_set_hl(0, "LineNr", { fg = "#7C6C82" })

-- GitSigns (example - customize as needed)
vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { fg = "#735665" })

local map = vim.keymap.set

-- Leader key
vim.g.mapleader = " "

-- Clipboard Operations
map({ "n", "v" }, "<Leader>p", '"+p')
map({ "n", "v" }, "<Leader>P", '"+P')
map({ "n", "v" }, "<leader>y", '"+y')
map({ "n", "v" }, "<leader>d", '"_d')
map("v", "<Leader>D", '"+d', { desc = "Delete selection to clipboard" })

-- Command Line Navigation
map("c", "<Up>", "<C-p>")
map("c", "<Down>", "<C-n>")

-- File Operations
map("n", "<Leader>w", ":w<CR>")
map("n", "<Leader>q", ":q!<CR>")
map("n", "<Leader>Q", ":qa!<CR>")
map("n", "<leader>x", "<cmd>silent! x<CR>", { desc = "Save and quit silently" })

-- Indentation
map("x", ">", ">gv")
map("x", "<", "<gv")

-- Buffers
map("n", "<S-h>", "<cmd>bprevious<CR>")
map("n", "<S-l>", "<cmd>bnext<CR>")
map("n", "<leader>bc", "<cmd>bd<CR>")

-- Window Management
map("n", "<Leader>bsv", "<cmd>vsplit<CR>")
map("n", "<Leader>bsh", "<cmd>split<CR>")
map("n", "<Leader>bwc", "<cmd>close<CR>")

-- Plugin Shortcuts
map("n", "<Space>rr", "<cmd>RustRun<CR>")
map("n", "<F8>", "<cmd>terminal npm run dev<CR>")

-- Remove J key behavior
-- vim.keymap.set({ "n", "v" }, "J", "<NOP>", { desc = "Disable J key" })

-- Basic Editor Options
vim.o.number = true
vim.o.relativenumber = true
vim.o.termguicolors = true
vim.o.wrap = false
vim.o.hidden = true
vim.o.showmode = false

-- Indentation
vim.o.expandtab = true
vim.o.tabstop = 2
vim.o.softtabstop = 2
vim.o.shiftwidth = 2

-- Undo/Backup
vim.opt.undofile = true
vim.opt.undodir = vim.fn.expand("~/.local/share/nvim/undo")
vim.opt.directory = "/tmp" -- Swap files

-- TESTING LAGGYNESS

-- History
vim.opt.shada = "'1000,<50,s10,h"
vim.opt.history = 10000

-- Create undo dir if missing
if vim.fn.isdirectory(vim.o.undodir) == 0 then
	vim.fn.mkdir(vim.o.undodir, "p")
end
