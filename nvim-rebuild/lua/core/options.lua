-- core/options.lua
-- Editor behavior. No plugins. No magic.

-- ── Line Numbers ──
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = "yes"

-- ── Indentation (2-space default, overrides in autocmds.lua) ──
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.softtabstop = 2
vim.o.smartindent = true

-- ── Search ──
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.hlsearch = true
vim.o.incsearch = true

-- ── Appearance ──
-- NOTE: termguicolors removed — Neovim auto-detects truecolor since 0.10
vim.o.cursorline = true
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8
vim.o.wrap = false

-- ── Splits ──
vim.o.splitbelow = true
vim.o.splitright = true

-- ── Undo / Backup ──
vim.o.undofile = true
vim.o.swapfile = false
vim.o.backup = false

-- ── Clipboard ──
vim.o.clipboard = "unnamedplus"

-- ── Misc ──
vim.o.mouse = "a"
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.opt.completeopt = { "menuone", "noselect" } -- vim.opt for table value
vim.o.showmode = false
