-- path: nvim/lua/plugins/ui/explorer.lua
-- Description: File explorer — yazi.nvim bridges the standalone yazi file manager
--              into Neovim as a floating window. One tool for file management
--              everywhere: tmux pane, bare terminal, AND inside Neovim.
--
-- WHY yazi.nvim over neo-tree/oil/nvim-tree:
--   - You already have yazi rebuilt with muscle memory locked in
--   - Same keybindings and workflow inside and outside Neovim
--   - Constitution: "the toolchain is one instrument"
--   - LSP rename sync: rename files in yazi → imports auto-update
--   - Telescope integration: <C-s> in yazi greps the current directory
--   - No second file tree to learn/configure/maintain
--
-- COMMANDS:
--   :Yazi          Open yazi at the current file's directory
--   :Yazi cwd      Open yazi at Neovim's working directory
--   :Yazi toggle   Resume the last yazi session (preserves position)
--
-- YAZI-INTERNAL KEYMAPS (active while yazi floating window is focused):
--   <C-v>          Open file in vertical split
--   <C-x>          Open file in horizontal split
--   <C-t>          Open file in new tab
--   <C-s>          Grep in current directory (uses your Telescope)
--   <C-q>          Send selected files to quickfix list
--   <C-y>          Copy relative path to selected file
--   <Tab>          Cycle through open Neovim buffers in yazi
--   <f1>           Show all yazi.nvim keymaps
--
-- CHANGELOG: 2026-02-10 | Initial creation — constitution-compliant | ROLLBACK: Delete file

return {
  "mikavilpas/yazi.nvim",
  version = "*",
  dependencies = {
    -- NOTE: plenary is already a dependency of telescope, so this adds zero weight
    { "nvim-lua/plenary.nvim", lazy = true },
  },

  -- ── Lazy Loading ──────────────────────────────────────────────────────
  -- Loads on keymap OR when Neovim opens a directory (hijacks netrw).
  -- event = "VeryLazy" is NOT needed because open_for_directories + init
  -- handles the directory case, and keys handles the keymap case.
  keys = {
    -- HHKB Tier 1: Space + single key — your most frequent file nav action
    {
      "<leader>e",
      "<cmd>Yazi<cr>",
      mode = { "n", "v" },
      desc = "Explorer: open at current file",
    },
    -- HHKB Tier 2: Space + chord — less frequent, open at project root
    {
      "<leader>E",
      "<cmd>Yazi cwd<cr>",
      desc = "Explorer: open at working directory",
    },
    -- HHKB Tier 2: Meta is thumb-accessible on HHKB — resume last session
    -- WHY: Toggle preserves your position in yazi from last use.
    -- Replaces the default <C-Up> which is HHKB Tier 4 (BANNED — Fn+arrow).
    {
      "<M-e>",
      "<cmd>Yazi toggle<cr>",
      desc = "Explorer: resume last session",
    },
  },

  ---@type YaziConfig | {}
  opts = {
    -- WHY: Opens yazi instead of netrw when you do `nvim .` or `:edit dir/`
    -- This is the core reason we're using yazi.nvim — one file manager everywhere.
    open_for_directories = true,

    -- WHY: All visible splits appear as yazi tabs for fast cross-file navigation.
    -- If you have 3 splits open, yazi shows them as tabs you can jump between.
    open_multiple_tabs = false,

    -- WHY: When you close yazi without picking a file, Neovim's cwd stays put.
    -- Set to true if you want `:cd` to follow yazi's directory on close.
    change_dir_on_close = false,

    -- ── Floating Window ───────────────────────────────────────────────
    -- WHY: 0.9 = 90% of terminal area. Large enough to work, small enough
    -- to see Neovim context behind it (especially with winblend).
    floating_window_scaling_factor = 0.9,

    -- WHY: Matches vim.o.winborder = "rounded" from core/options.lua
    yazi_floating_window_border = "rounded",

    -- WHY: Slight transparency so you can see Neovim behind yazi.
    -- 0 = opaque, 100 = invisible. 10-15 is the sweet spot.
    yazi_floating_window_winblend = 10,

    -- ── Keymaps (inside yazi floating window) ─────────────────────────
    -- These are active ONLY when the yazi floating window is focused.
    -- They don't conflict with any Neovim or tmux keymaps.
    keymaps = {
      show_help = "<f1>",
      open_file_in_vertical_split = "<C-v>",
      open_file_in_horizontal_split = "<C-x>",
      open_file_in_tab = "<C-t>",
      grep_in_directory = "<C-s>",
      replace_in_directory = "<C-g>",
      cycle_open_buffers = "<Tab>",
      copy_relative_path_to_selected_files = "<C-y>",
      send_to_quickfix_list = "<C-q>",
    },

    -- ── Buffer Highlighting ───────────────────────────────────────────
    -- WHY: When hovering files in yazi, Neovim highlights the corresponding
    -- buffer if it's open. Visual feedback showing "this file is already open."
    highlight_hovered_buffers_in_same_directory = true,

    -- ── Integrations ──────────────────────────────────────────────────
    -- Telescope grep auto-detected since telescope.nvim is installed.
    -- grug-far.nvim replace auto-detected if installed (Phase 3 consideration).
    -- No explicit config needed — yazi.nvim detects installed plugins.
  },

  -- ── Init (runs before plugin loads) ─────────────────────────────────
  -- WHY: With open_for_directories = true, we must prevent netrw from loading
  -- first. This tells Neovim "netrw is already loaded" so it doesn't compete.
  -- NOTE: gx (open URL/file under cursor) is INDEPENDENT of netrw in 0.11+ —
  -- it uses vim.ui.open() natively. Disabling netrwPlugin does NOT break gx.
  init = function()
    vim.g.loaded_netrwPlugin = 1
  end,
}
