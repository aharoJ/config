---@diagnostic disable: undefined-global
-- Indentation
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- File Operations
vim.keymap.set("n", "<Leader>w", ":w<CR>", { desc = "" })
vim.keymap.set("n", "<Leader>Q", ":qa!<CR>", { desc = "" })
vim.keymap.set("n", "<leader>X", "<cmd>silent! x<CR>", { desc = "Save and quit silently" })

-- Indentation
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Buffers
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "[buf] prev" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<CR>", { desc = "[buf] next" })
vim.keymap.set("n", "<leader>bc", "<cmd>bd<CR>", { desc = "" })

