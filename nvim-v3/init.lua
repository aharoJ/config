-- path: ~/.config/nvim-v3/init.lua
-- description: Clean-slate Neovim 0.12.0 config (v3)
-- date: 2026-04-02

-- ============================================================================
-- Leader (must be before any keymap)
-- ============================================================================
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ============================================================================
-- Options
-- ============================================================================
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.termguicolors = true

-- Tabs / indent
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true

-- Scrolling
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.smoothscroll = true

-- Splits
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Clipboard
vim.opt.clipboard = "unnamedplus"

-- Mouse
vim.opt.mouse = "a"

-- Recovery
vim.opt.undofile = true
vim.opt.swapfile = true
vim.opt.backup = true
vim.opt.undodir = vim.fn.expand("~/.local/share/nvim-v3/undo//")
vim.opt.backupdir = vim.fn.expand("~/.local/share/nvim-v3/backup//")
vim.opt.directory = vim.fn.expand("~/.local/share/nvim-v3/swap//")

-- Ensure recovery dirs exist
for _, dir in ipairs({ vim.o.undodir, vim.o.backupdir, vim.o.directory }) do
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

-- Folding (treesitter-powered, all open by default)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevelstart = 99

-- Misc
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.completeopt = { "menu", "menuone", "popup", "nearest" }
vim.opt.showmode = false
vim.opt.shell = "/opt/homebrew/bin/fish"

-- Popup menu border (0.12 native)
vim.opt.pumborder = "rounded"
vim.opt.pummaxwidth = 80

-- Global floating window border (D11 — C11: may double-border plugin floats)
vim.opt.winborder = "rounded"

-- Restore viewport on tagstack jumps (D20)
vim.opt.jumpoptions:append("view")

-- ============================================================================
-- UI2 (experimental — 0.12 native cmdline/messages)
-- ============================================================================
local ok_ui2, ui2 = pcall(require, "vim._core.ui2")
if ok_ui2 then
  pcall(ui2.enable)
end

-- ============================================================================
-- Build hooks (C2 — must be before vim.pack.add)
-- ============================================================================
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.spec.name == "kanagawa.nvim" and ev.data.kind ~= "delete" then
      vim.cmd("KanagawaCompile")
    end
  end,
})

-- ============================================================================
-- Plugins (vim.pack — D1)
-- ============================================================================
vim.pack.add({
  "https://github.com/rebelot/kanagawa.nvim",
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/christoomey/vim-tmux-navigator",
})

-- ============================================================================
-- Colorscheme (D8)
-- ============================================================================
require("kanagawa").setup({
  compile = true,
  theme = "wave",
  background = { dark = "wave", light = "lotus" },
})
vim.cmd.colorscheme("kanagawa")

-- ============================================================================
-- fzf-lua (D5)
-- ============================================================================
require("fzf-lua").setup({ "default-title" })

vim.keymap.set("n", "<leader>ff", function() require("fzf-lua").files() end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", function() require("fzf-lua").live_grep() end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", function() require("fzf-lua").buffers() end, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fh", function() require("fzf-lua").help_tags() end, { desc = "Help tags" })
vim.keymap.set("n", "<leader>fr", function() require("fzf-lua").resume() end, { desc = "Resume last" })
vim.keymap.set("n", "<leader>fo", function() require("fzf-lua").oldfiles() end, { desc = "Recent files" })
vim.keymap.set("n", "<leader>fd", function() require("fzf-lua").diagnostics_workspace() end, { desc = "Diagnostics" })
vim.keymap.set("n", "<leader>fs", function() require("fzf-lua").lsp_workspace_symbols() end, { desc = "Symbols" })

-- ============================================================================
-- gitsigns (D9)
-- ============================================================================
require("gitsigns").setup({
  on_attach = function(bufnr)
    local gs = require("gitsigns")
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end
    map("n", "]h", gs.next_hunk, "Next hunk")
    map("n", "[h", gs.prev_hunk, "Prev hunk")
    map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
    map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
    map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage")
    map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
    map("n", "<leader>hb", gs.blame_line, "Blame line")
    map("n", "<leader>hd", gs.diffthis, "Diff this")
  end,
})

-- ============================================================================
-- conform.nvim (D7)
-- ============================================================================
require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "black" },
    javascript = { "prettierd", "prettier", stop_after_first = true },
    typescript = { "prettierd", "prettier", stop_after_first = true },
    typescriptreact = { "prettierd", "prettier", stop_after_first = true },
    javascriptreact = { "prettierd", "prettier", stop_after_first = true },
    json = { "prettierd", "prettier", stop_after_first = true },
    markdown = { "prettierd", "prettier", stop_after_first = true },
    rust = { "rustfmt" },
    java = { "google-java-format" },
    fish = { "fish_indent" },
    sh = { "shfmt" },
    toml = { "taplo" },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_format = "fallback",
  },
})

vim.keymap.set("n", "<leader>cf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })

-- ============================================================================
-- Statusline (D3 — native expression, no plugin)
-- ============================================================================
function _G.statusline()
  local branch = vim.b.gitsigns_head and (" " .. vim.b.gitsigns_head) or ""
  local diag = vim.diagnostic.status() or ""
  local prog = vim.ui.progress_status() or ""
  local rec = vim.fn.reg_recording()
  local ok_busy, busy_val = pcall(function() return vim.bo.busy end)
  local is_busy = ok_busy and busy_val ~= 0 and busy_val ~= false
  return table.concat({
    " %f", "%m%r",
    branch,
    rec ~= "" and (" REC @" .. rec) or "",
    "%=",
    is_busy and " " or "",
    diag ~= "" and (" " .. diag) or "",
    prog ~= "" and (" " .. prog) or "",
    " %y",
    " %l:%c %p%% ",
  })
end

vim.o.statusline = "%!v:lua.statusline()"

-- ============================================================================
-- Keymaps
-- ============================================================================
local map = vim.keymap.set

-- Window navigation (Ctrl+hjkl handled by vim-tmux-navigator)

-- Window resize
map("n", "<M-h>", "<cmd>vertical resize -2<cr>", { desc = "Shrink width" })
map("n", "<M-l>", "<cmd>vertical resize +2<cr>", { desc = "Grow width" })
map("n", "<M-j>", "<cmd>resize -2<cr>", { desc = "Shrink height" })
map("n", "<M-k>", "<cmd>resize +2<cr>", { desc = "Grow height" })

-- Centered navigation
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up" })
map("n", "n", "nzzzv", { desc = "Next search (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev search (centered)" })

-- Move selections
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })

-- Join without cursor jump
map("n", "J", "mzJ`z", { desc = "Join lines" })

-- Paste without clobbering register
map("x", "p", '"_dP', { desc = "Paste (keep register)" })

-- Delete to void register
map({ "n", "v" }, "<leader>d", '"_d', { desc = "Delete to void" })
map("n", "x", '"_x', { desc = "Delete char to void" })

-- Indent and stay selected
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Save
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })

-- Buffer
map("n", "<leader><leader>", "<C-^>", { desc = "Alternate buffer" })
map("n", "<leader>bc", "<cmd>bd<cr>", { desc = "Close buffer" })

-- Replace word under cursor
map("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace word" })

-- Make file executable
map("n", "<leader>x", function()
  local path = vim.fn.expand("%:p")
  if path == "" then vim.notify("No file to chmod") return end
  vim.fn.system({ "chmod", "+x", path })
  vim.notify("chmod +x " .. vim.fn.expand("%:t"))
end, { desc = "Make executable" })

-- Built-in tools (D12, D13)
map("n", "<leader>u", "<cmd>Undotree<cr>", { desc = "Undo tree" })
map("n", "<leader>gD", "<cmd>DiffTool<cr>", { desc = "Diff tool" })

-- Terminal escape (double-Esc to avoid intercepting TUI programs like yazi/lazygit)
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal" })

-- ============================================================================
-- Autocommands
-- ============================================================================
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Trim trailing whitespace on save (skip binary, special buffers, markdown)
autocmd("BufWritePre", {
  group = augroup("trim-whitespace", { clear = true }),
  callback = function()
    if vim.bo.binary or vim.bo.buftype ~= "" or vim.bo.filetype == "markdown" then return end
    local view = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Return to last edit position
autocmd("BufReadPost", {
  group = augroup("last-position", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Detect external file changes
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("checktime", { clear = true }),
  command = "checktime",
})

-- Auto-resize splits on terminal resize
autocmd("VimResized", {
  group = augroup("resize-splits", { clear = true }),
  command = "tabdo wincmd =",
})

-- Auto-create parent directories on save
autocmd("BufWritePre", {
  group = augroup("auto-mkdir", { clear = true }),
  callback = function(event)
    if event.match:match("^%w%w+://") then return end
    local dir = vim.fn.fnamemodify(event.file, ":p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})

-- Terminal: no line numbers, auto insert mode
autocmd("TermOpen", {
  group = augroup("term-config", { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.cmd("startinsert")
  end,
})

-- Close certain filetypes with q
autocmd("FileType", {
  group = augroup("close-with-q", { clear = true }),
  pattern = { "help", "qf", "man", "lspinfo", "checkhealth", "notify", "undotree" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Filetype-specific indent
autocmd("FileType", {
  group = augroup("ft-indent", { clear = true }),
  pattern = { "python" },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
  end,
})

autocmd("FileType", {
  group = augroup("ft-indent-go", { clear = true }),
  pattern = { "go" },
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
})

-- Redraw statusline on LSP progress updates (keeps progress/busy indicators fresh)
autocmd("LspProgress", {
  group = augroup("lsp-progress-redraw", { clear = true }),
  callback = function() vim.cmd.redrawstatus() end,
})

-- LSP attach keymaps (servers configured in Phase 3 via lsp/ directory)
-- 0.12 defaults already provide: gd, gD, grr, gra, grn, gri, grt, grx, K, ]d, [d
-- Only add <leader> aliases that don't conflict with defaults
autocmd("LspAttach", {
  group = augroup("lsp-keymaps", { clear = true }),
  callback = function(event)
    local buf = event.buf
    local m = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end
    m("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
    m("n", "<leader>cr", vim.lsp.buf.rename, "Rename")
    m("n", "<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
    m("n", "<leader>cl", function() vim.lsp.codelens.run() end, "CodeLens run")
    vim.lsp.codelens.enable(true, { bufnr = buf })
  end,
})
