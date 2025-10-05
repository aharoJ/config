-- path: nvim/lua/core/clipboard.lua

-- ── Clipboard (minimal, dot-repeat friendly) ────────────────────────────────
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { desc = "[clip] yank"})
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { desc = "[clip] paste after"})
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P', { desc = "[clip] paste"})
vim.keymap.set("v", "<leader>d", '"+d', { desc = "[clip] delete into clip" })
vim.keymap.set({ "n", "v" }, "<leader>D", '"_d', { desc = "[clip] delete _" })
