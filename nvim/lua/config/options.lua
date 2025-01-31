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
