-- nvim/lua/settings/keymaps.lua

local map = vim.keymap.set

-- Leader key
vim.g.mapleader = " "

-- Clipboard Operations
map({ "n", "v" }, "<Leader>p", '"+p')
map({ "n", "v" }, "<Leader>P", '"+P')
map({ "n", "v" }, "<leader>y", '"+y')
map({ "n", "v" }, "<leader>d", '"_d', { desc = "delete without yanking" })
map("v", "<Leader>D", '"+d', { desc = "delete selection to clipboard" })

-- Command Line Navigation
map("c", "<Up>", "<C-p>")
map("c", "<Down>", "<C-n>")

-- File Operations
map("n", "<Leader>w", ":w<CR>", { desc = "" })
map("n", "<Leader>q", ":q!<CR>", { desc = "" })
map("n", "<Leader>Q", ":qa!<CR>", { desc = "" })
map("n", "<leader>X", "<cmd>silent! x<CR>", { desc = "Save and quit silently" })

-- Indentation
-- map("x", ">", ">gv")
-- map("x", "<", "<gv")
map("v", "<", "<gv", { desc = "Indent left and reselect" })
map("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Buffers
-- map("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "[buf] prev" })
-- map("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "[buf] next" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "[buf] prev" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "[buf] next" })
map("n", "<leader>bc", "<cmd>bd<CR>", { desc = "" })

-- Window Management
map("n", "<Leader>bsv", "<cmd>vsplit<CR>", { desc = "[win] split vertical" })
map("n", "<Leader>bsh", "<cmd>split<CR>", { desc = "[win] split horizantal" })
map("n", "<Leader>bwc", "<cmd>close<CR>", { desc = "[win] close" })

-- Plugin Shortcuts
map("n", "<Space>rr", "<cmd>RustRun<CR>", { desc = "Run Rust" })
map("n", "<F8>", "<cmd>terminal npm run dev<CR>", { desc = "" })

-- Remove J key behavior
vim.keymap.set({ "n", "v" }, "J", "<NOP>", { desc = "Disable J key" })

-- Center screen when jumping
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })

-- Move lines up/down
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
