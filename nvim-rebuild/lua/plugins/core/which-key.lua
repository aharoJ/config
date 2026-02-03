-- path: nvim/lua/plugins/core/which-key.lua
-- Description: Keymap discovery popup. Auto-discovers all desc-annotated keymaps.
--              Group labels define the namespace system (Article VI).
--              No keymaps are created here except <leader>? — all others come
--              from core/keymaps.lua or individual plugin specs.
-- CHANGELOG: 2026-02-03 | Created: which-key v3 config, classic preset, no icons | ROLLBACK: Delete file

return {
  "folke/which-key.nvim",
  event = "VeryLazy",

  keys = {
    {
      "<leader>?",
      function() require("which-key").show({ global = false }) end,
      desc = "Buffer-local keymaps",
    },
  },

  opts = {
    -- ── Layout ──────────────────────────────────────────────────
    preset = "classic",

    -- ── Delay ───────────────────────────────────────────────────
    -- WHY: Independent of timeoutlen (300ms in options.lua).
    -- Default: 0ms for plugin triggers (marks, registers, spelling),
    -- 200ms for everything else. Sane out of the box — don't override.

    -- ── Plugins (built-in discoverability aids) ─────────────────
    plugins = {
      marks = true,                   -- Show marks on ' and `
      registers = true,               -- Show registers on " (normal) / <C-r> (insert)
      spelling = {
        enabled = true,               -- z= shows suggestions in which-key popup
        suggestions = 20,
      },
      presets = {
        operators = true,             -- Help for d, y, c, etc.
        motions = true,               -- Help for motions
        text_objects = true,          -- Help for text objects after entering operator
        windows = true,               -- <C-w> bindings (Ctrl is HHKB home-row — use often)
        nav = true,                   -- Misc navigation bindings
        z = true,                     -- Folds, spelling, z-prefixed commands
        g = true,                     -- g-prefixed commands (includes 0.11 LSP defaults: grn, grr, gra, gri, gO)
      },
    },

    -- ── Icons ───────────────────────────────────────────────────
    -- WHY: Minimal aesthetic. To try icons: set mappings = true (requires Nerd Font — already patched in terminal).
    icons = {
      mappings = false,
    },

    -- ── Group Labels (Article VI namespace system) ──────────────
    -- WHY: which-key auto-discovers desc from vim.keymap.set, but groups
    -- need explicit labels. These define the <leader> namespace hierarchy.
    spec = {
      -- Active groups (keymaps exist in core/keymaps.lua)
      { "<leader>b", group = "Buffer" },
      { "<leader>q", group = "Quickfix" },

      -- Reserved groups (keymaps added in Phase 2/3)
      -- { "<leader>f", group = "Find" },
      -- { "<leader>g", group = "Git" },
      -- { "<leader>l", group = "LSP", mode = { "n", "v" } },
      -- { "<leader>t", group = "Terminal" },
      -- { "<leader>e", group = "Explorer" },
      -- { "<leader>c", group = "Code", mode = { "n", "v" } },
    },

    -- ── Window ──────────────────────────────────────────────────
    -- WHY: Border inherits from vim.o.winborder = "rounded" (0.11+).
    -- No need to set border here — the global setting handles it.
  },
}
