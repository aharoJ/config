-- path: nvim/lua/core/clipboard.lua
-- ───────────── (inverted logic: yy → system, <leader>y → internal) ─────────────

-- 1️⃣ Default yanks go to system clipboard
vim.opt.clipboard = "unnamedplus"

-- 2️⃣ Make all deletes and changes *not* affect yank registers
vim.keymap.set({ "n", "v" }, "d", '"_d', { noremap = true })
vim.keymap.set({ "n", "v" }, "D", '"_D', { noremap = true })
vim.keymap.set({ "n", "v" }, "x", '"_x', { noremap = true })
vim.keymap.set({ "n", "v" }, "c", '"_c', { noremap = true })
vim.keymap.set({ "n", "v" }, "C", '"_C', { noremap = true })

-- 3️⃣ <leader> versions go to internal 0-register (local yank/paste cycle)
vim.keymap.set({ "n", "v" }, "<leader>d", '"0d', { desc = "[local] delete keep internal" })
vim.keymap.set({ "n", "v" }, "<leader>D", '"0D', { desc = "[local] delete line keep internal" })
vim.keymap.set({ "n", "v" }, "<leader>c", '"0c', { desc = "[local] change keep internal" })
vim.keymap.set({ "n", "v" }, "<leader>C", '"0C', { desc = "[local] change line keep internal" })

-- 4️⃣ Internal-only yanking and pasting
vim.keymap.set({ "n", "v" }, "<leader>y", '"0y', { desc = "[local] yank only" })
vim.keymap.set({ "n", "v" }, "<leader>p", '"0p', { desc = "[local] paste only" })
vim.keymap.set({ "n", "v" }, "<leader>P", '"0P', { desc = "[local] paste before" })

-- 5️⃣ Paste in visual mode *without* yanking the selectio
vim.keymap.set("x", "p", '"_dP', { noremap = true, desc = "paste without overwriting register" })
vim.keymap.set("x", "P", '"_dP', { noremap = true, desc = "paste without overwriting register" })
