-- path: nvim/lua/plugins/core/colorscheme.lua
-- Description: Catppuccin Mocha. Loads first (lazy=false, priority=1000).
--              Integrations are ONLY listed for plugins that actually exist in this config.
-- CHANGELOG: 2026-02-03 | Removed dead integrations (cmp). Added mason, blink_cmp integrations
--            for Phase 2 editor stack. | ROLLBACK: Restore previous colorscheme.lua

return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = {
    flavour = "mocha",
    transparent_background = false,
    integrations = {
      -- Phase 1 plugins
      gitsigns = true,
      treesitter = true,
      telescope = { enabled = true },

      -- Phase 2 plugins
      mason = true,
      blink_cmp = true,
      native_lsp = {
        enabled = true,
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },

      -- Phase 3 (uncomment when plugins are added)
      -- indent_blankline = { enabled = true },
      -- which_key = true,
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
