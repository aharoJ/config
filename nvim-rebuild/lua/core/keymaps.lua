-- path: nvim/lua/core/keymaps.lua
-- Description: ALL plugin-free keybindings. Organized by purpose.
--              Plugin keymaps belong in lua/plugins/<category>/<plugin>.lua
-- CHANGELOG: 2026-02-03 | Full rewrite: HHKB-optimized, constitution v2.2 | ROLLBACK: Replace with previous keymaps.lua

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
-- gcc / gc      → Comment toggle (built-in since 0.10)
-- gx            → Open URL/filepath under cursor
-- ──────────────────────────────────────────────────────────────────────────

local keymap = vim.keymap.set

-- ── UNIVERSAL PATTERNS ──────────────────────────────────────

-- Move selected lines up/down in visual mode
-- WHY: Rearranging code without cut/paste. Near-universal among power users.
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Join lines without cursor jumping
-- WHY: Default J moves cursor to join point. This preserves position.
keymap("n", "J", "mzJ`z", { desc = "Join lines (cursor stays)" })

-- Half-page jump with centered cursor
-- WHY: Keeps context visible during fast navigation. <C-> is HHKB home-row Ctrl.
keymap("n", "<C-d>", "<C-d>zz", { desc = "Half-page down (centered)" })
keymap("n", "<C-u>", "<C-u>zz", { desc = "Half-page up (centered)" })

-- Search terms stay centered
-- WHY: After searching, you want to SEE the match in context, not at screen edge.
keymap("n", "n", "nzzzv", { desc = "Next search result (centered)" })
keymap("n", "N", "Nzzzv", { desc = "Prev search result (centered)" })

-- ── CLIPBOARD (pragmatic: y just works, deletes don't pollute) ───
-- Paste over selection without losing register
-- WHY: Default visual p/P replaces your yank with deleted text. P is redundant in visual mode (same as p), so repurpose it for no-clobber paste.
keymap("x", "P", '"_dP', { desc = "Paste over without register loss" })

-- Delete to void register (opt-in for throwaway deletes)
-- WHY: With unnamedplus, d pollutes clipboard. Use this when removing junk.
keymap({ "n", "v" }, "<leader>d", '"_d', { desc = "Delete to void register" })

-- Single char delete to void
-- WHY: x on a typo should never overwrite your carefully yanked code.
keymap("n", "x", '"_x', { desc = "Delete char without yank" })

-- ── WINDOW NAVIGATION ───────────────────────────────────────
-- HHKB: Ctrl is home row left, so <C-hjkl> is Tier 1 comfort.
keymap("n", "<C-h>", "<C-w>h", { desc = "Move to left split" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Move to below split" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Move to above split" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Move to right split" })

-- ── WINDOW RESIZING (HHKB: Meta is thumb, NO arrow keys) ────
-- WHY: HHKB - Meta/Alt is thumb-accessible on HHKB. <M-hjkl> is Tier 2 comfort.
keymap("n", "<M-h>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
keymap("n", "<M-l>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })
keymap("n", "<M-j>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
keymap("n", "<M-k>", "<cmd>resize +2<CR>", { desc = "Increase window height" })

-- ── BUFFER MANAGEMENT ───────────────────────────────────────
-- NOTE: [b / ]b handle next/prev via 0.11 built-in defaults. No duplication needed.
keymap("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })
keymap("n", "<leader><leader>", "<C-^>", { desc = "Alternate buffer (last file)" })

-- ── TERMINAL MODE ───────────────────────────────────────────
-- WHY: Clean escape path from terminal insert mode back to Normal.
keymap("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal insert mode" })
keymap("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Terminal: move to left split" })
keymap("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Terminal: move to below split" })
keymap("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Terminal: move to above split" })
keymap("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Terminal: move to right split" })

-- ── QUALITY OF LIFE ─────────────────────────────────────────

-- Quick save
keymap("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })

-- Select all
keymap("n", "<leader>a", "ggVG", { desc = "Select all" })

-- Quit
keymap("n", "<leader>qq", "<cmd>q!<CR>", { desc = "Quit" })


-- Clear search highlight on Escape
-- NOTE: No <Esc> → nohlsearch needed. hlsearch=false means highlights never persist.

-- Word replace under cursor (fastest refactor motion in vanilla vim)
keymap("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace word under cursor globally" })
keymap("v", "<leader>s", function() vim.cmd('noau normal! "zy') local text = vim.fn.getreg("z") local escaped = vim.fn.escape(text, [[/\]]) local cmd = ":%s/\\V\\C" .. escaped .. "/" .. escaped .. "/g" vim.api.nvim_feedkeys( vim.api.nvim_replace_termcodes(cmd .. string.rep("<Left>", 2), true, false, true), "n", false) end, { desc = "Replace selection globally" })



-- Make current file executable
keymap("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true, desc = "Make file executable" })

-- Better indenting (stay in visual mode)
-- WHY: Default < and > drop you out of visual mode. This lets you indent repeatedly.
keymap("v", "<", "<gv", { desc = "Indent left (stay selected)" })
keymap("v", ">", ">gv", { desc = "Indent right (stay selected)" })

-- ── QUICKFIX NAVIGATION ─────────────────────────────────────
-- WHY: Quickfix is the primary multi-file navigation tool in vanilla vim.
keymap("n", "<leader>qn", "<cmd>cnext<CR>zz", { desc = "Next quickfix item" })
keymap("n", "<leader>qp", "<cmd>cprev<CR>zz", { desc = "Prev quickfix item" })
keymap("n", "<leader>qo", "<cmd>copen<CR>", { desc = "Open quickfix list" })
keymap("n", "<leader>qc", "<cmd>cclose<CR>", { desc = "Close quickfix list" })
