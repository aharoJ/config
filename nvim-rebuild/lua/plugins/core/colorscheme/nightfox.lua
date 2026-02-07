-- plugins/core/colorscheme/nightfox.lua
-- Nightfox — Multiple variants, well-engineered. One of the most versatile themes.
-- Variants: nightfox, dayfox, dawnfox, duskfox, nordfox, terafox, carbonfox
--
-- PALETTE REFERENCE (Nightfox - default):
--   bg0          #131a24   (darkest bg)
--   bg1          #192330   (main bg)
--   bg2          #212e3f   (elevated bg)
--   bg3          #29394f   (selection bg)
--   bg4          #39506d   (visual bg)
--   fg0          #d6d6d7   (bright text)
--   fg1          #cdcecf   (main text)
--   fg2          #aeafb0   (secondary text)
--   fg3          #71839b   (tertiary text)
--   sel0         #2b3b51   (selection bg)
--   sel1         #3c5372   (selection fg)
--   comment      #738091   (comments)
--   black        #393b44   (terminal black)
--   red          #c94f6d   (red - errors)
--   green        #81b29a   (green - strings)
--   yellow       #dbc074   (yellow - warnings)
--   blue         #719cd6   (blue - functions)
--   magenta      #9d79d6   (purple - keywords)
--   cyan         #63cdcf   (cyan)
--   white        #dfdfe0   (white)
--   orange       #f4a261   (orange)
--   pink         #d67ad2   (pink)
--
-- OTHER VARIANTS:
--   duskfox: Warmer, purple-tinted (great for rose-pine lovers)
--   terafox: Earth tones, green-tinted (great for everforest lovers)
--   carbonfox: Grayscale, minimal color
--   nordfox: Nord-inspired
--   dayfox: Light mode
--   dawnfox: Warm light mode

return {
  "EdenEast/nightfox.nvim",
  name = "nightfox",
  lazy = false,
  enabled = false, -- 👈 flip to true to activate
  priority = 1000,
  opts = {
    options = {
      compile_path = vim.fn.stdpath("cache") .. "/nightfox",
      compile_file_suffix = "_compiled",
      transparent = false,
      terminal_colors = true,
      dim_inactive = false,
      module_default = true,
      colorblind = {
        enable = false,
        simulate_only = false,
        severity = {
          protan = 0,
          deutan = 0,
          tritan = 0,
        },
      },
      styles = {
        comments = "italic",
        conditionals = "NONE",
        constants = "NONE",
        functions = "NONE",
        keywords = "NONE",
        numbers = "NONE",
        operators = "NONE",
        strings = "NONE",
        types = "NONE",
        variables = "NONE",
      },
      inverse = {
        match_paren = false,
        visual = false,
        search = false,
      },
    },
    palettes = {},
    specs = {},
    groups = {
      all = {
        -- Telescope
        TelescopeBorder = { fg = "bg4", bg = "bg1" },
        TelescopePromptBorder = { fg = "bg4", bg = "bg2" },
        TelescopePromptNormal = { bg = "bg2" },
        TelescopePromptTitle = { fg = "bg1", bg = "blue", style = "bold" },
        TelescopeResultsBorder = { fg = "bg4", bg = "bg1" },
        TelescopeResultsNormal = { bg = "bg1" },
        TelescopeResultsTitle = { fg = "bg1", bg = "bg1" },
        TelescopePreviewBorder = { fg = "bg4", bg = "bg1" },
        TelescopePreviewNormal = { bg = "bg1" },
        TelescopePreviewTitle = { fg = "bg1", bg = "green", style = "bold" },
        TelescopeSelection = { bg = "sel0", style = "bold" },
        TelescopeSelectionCaret = { fg = "cyan", bg = "sel0" },

        -- Completion
        CmpItemKindClass = { fg = "yellow" },
        CmpItemKindInterface = { fg = "cyan" },
        CmpItemKindFunction = { fg = "blue" },
        CmpItemKindMethod = { fg = "blue" },
        CmpItemKindVariable = { fg = "magenta" },
        CmpItemKindField = { fg = "cyan" },
        CmpItemKindProperty = { fg = "cyan" },
        CmpItemKindConstant = { fg = "orange" },
        CmpItemKindKeyword = { fg = "magenta" },
        CmpItemKindSnippet = { fg = "green" },
        CmpItemKindText = { fg = "fg1" },

        -- Git signs
        GitSignsAdd = { fg = "green" },
        GitSignsChange = { fg = "yellow" },
        GitSignsDelete = { fg = "red" },
      },
    },
  },
  config = function(_, opts)
    require("nightfox").setup(opts)
    vim.cmd.colorscheme("nightfox") -- or duskfox, terafox, carbonfox, nordfox, dayfox, dawnfox
  end,
}
