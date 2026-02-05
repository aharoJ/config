-- plugins/colorscheme/rose-pine.lua
-- Rose Pine — Cozy, muted pinks and warm tones
-- Vibes with your CVMApp soft-rose accents. Moon variant is the sweet spot.

return {
  "rose-pine/neovim",
  name = "rose-pine",
  enabled= false,
  lazy = false,
  priority = 1000,
  opts = {
    variant = "moon", -- main, moon (darker), dawn (light)
    dark_variant = "moon",
    dim_inactive_windows = false,
    extend_background_behind_borders = true,

    styles = {
      bold = true,
      italic = true,
      transparency = false,
    },

    groups = {
      border = "muted",
      link = "iris",
      panel = "surface",

      error = "love",
      hint = "iris",
      info = "foam",
      note = "pine",
      todo = "rose",
      warn = "gold",

      git_add = "foam",
      git_change = "rose",
      git_delete = "love",
      git_dirty = "rose",
      git_ignore = "muted",
      git_merge = "iris",
      git_rename = "pine",
      git_stage = "iris",
      git_text = "rose",
      git_untracked = "subtle",

      h1 = "iris",
      h2 = "foam",
      h3 = "rose",
      h4 = "gold",
      h5 = "pine",
      h6 = "foam",
    },

    highlight_groups = {
      -- Cleaner UI elements
      StatusLine = { fg = "love", bg = "love", blend = 10 },
      StatusLineNC = { fg = "subtle", bg = "surface" },

      -- Telescope
      -- TelescopeBorder = { fg = "highlight_high", bg = "none" },
      -- TelescopeNormal = { bg = "none" },
      -- TelescopePromptNormal = { bg = "base" },
      -- TelescopeResultsNormal = { fg = "subtle", bg = "none" },
      -- TelescopeSelection = { fg = "text", bg = "highlight_med" },
      -- TelescopeSelectionCaret = { fg = "rose", bg = "highlight_med" },

      -- Completion
      CmpItemKindText = { fg = "gold" },
      CmpItemKindMethod = { fg = "iris" },
      CmpItemKindFunction = { fg = "iris" },
      CmpItemKindVariable = { fg = "foam" },
      CmpItemKindKeyword = { fg = "pine" },
      CmpItemKindSnippet = { fg = "rose" },

      -- Treesitter context
      TreesitterContext = { bg = "surface" },
      TreesitterContextLineNumber = { fg = "muted", bg = "surface" },

      -- Indent guides
      IndentBlanklineChar = { fg = "highlight_low" },
      IndentBlanklineContextChar = { fg = "rose" },
    },
  },
  config = function(_, opts)
    require("rose-pine").setup(opts)
    vim.cmd.colorscheme("rose-pine")
  end,
}
