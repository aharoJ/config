-- core/keymaps.lua
-- Essential keybinds only. Plugin keymaps go in their own plugin files.
-- Leader is set in init.lua (before lazy loads, per official recommendation).

-- ── Neovim 0.11 Built-in Defaults (DO NOT override) ──────────────────────
-- [d / ]d       → Diagnostic navigation
-- [D / ]D       → First / last diagnostic
-- [b / ]b       → Previous / next buffer
-- [B / ]B       → First / last buffer
-- <C-w>d        → Open diagnostic float
-- K             → LSP hover
-- grn           → LSP rename
-- grr           → LSP references
-- gri           → LSP implementation
-- gra           → LSP code action (Normal + Visual)
-- gO            → LSP document symbols
-- <C-S> (insert)→ LSP signature help
-- ──────────────────────────────────────────────────────────────────────────

local map = vim.keymap.set

-- ── Better Escape ──
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- ── Window Navigation ──
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to below window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to above window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- ── Window Resize ──
map("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase window width" })

-- ── Buffer Navigation (ergonomic aliases — [b/]b also work via 0.11 defaults) ──
map("n", "<S-l>", ":bnext<CR>", { desc = "Next buffer" })
map("n", "<S-h>", ":bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>x", ":bdelete<CR>", { desc = "Close buffer" })

-- ── Move Lines ──
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- ── Better Indenting ──
map("v", "<", "<gv", { desc = "Indent left and reselect" })
map("v", ">", ">gv", { desc = "Indent right and reselect" })

-- ── Clear Search Highlight ──
map("n", "<Esc>", ":nohlsearch<CR>", { desc = "Clear search highlight" })

-- ── Keep Cursor Centered ──
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down centered" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up centered" })
map("n", "n", "nzzzv", { desc = "Next search result centered" })
map("n", "N", "Nzzzv", { desc = "Previous search result centered" })

-- ── Paste Without Losing Register ──
map("x", "<leader>p", '"_dP', { desc = "Paste without yanking replaced text" })

-- ── Quick Save / Quit ──
map("n", "<leader>w", ":w<CR>", { desc = "Save file" })
map("n", "<leader>q", ":q<CR>", { desc = "Quit" })
