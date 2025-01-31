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
