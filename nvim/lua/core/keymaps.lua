-- path: nvim/lua/core/keymaps.lua
---@diagnostic disable: param-type-mismatch,undefined-global

-- ── Indentation ───────────────────────────────────────────────────────────────────
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- ── File Operations ───────────────────────────────────────────────────────────────────
vim.keymap.set("n", "<Leader>w", ":w<CR>", { desc = "write" })
vim.keymap.set("n", "<Leader>q", ":q!<CR>", { desc = "quit" })
vim.keymap.set("n", "<Leader>Q", ":qa!<CR>", { desc = "!QUIT" })
-- vim.keymap.set("n", "<leader>X", "<cmd>silent! x<CR>", { desc = "Save and quit silently" })
vim.keymap.set("n", "<leader>X", function() local ok = pcall(vim.cmd, "wall") if ok then vim.cmd("qall") else vim.notify("Write failed somewhere — not quitting.", vim.log.levels.ERROR) end end, { desc = "Write ALL and quit (safe)" })

-- ── Buffers ───────────────────────────────────────────────────────────────────
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "[buf] prev" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<CR>", { desc = "[buf] next" })
vim.keymap.set("n", "<leader>bc", "<cmd>bd<CR>", { desc = "[buf] close" })
vim.keymap.set("n", "<leader>bC", "<cmd>%bd|e#<CR>", { desc = "[buf] close ." })


-- ── HARDCORE EDITING ───────────────────────────────────────────────────────────────────
vim.keymap.set({"n", "v"}, "<M-j>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set({"n", "v"}, "<M-k>", ":m .-2<CR>==", { desc = "Move line up" })

