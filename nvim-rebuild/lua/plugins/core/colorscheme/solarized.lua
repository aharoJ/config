-- plugins/core/colorscheme/solarized.lua
-- Solarized — Scientific precision, love-it-or-hate-it. The thinking person's theme.
-- Designed with color theory. Both light and dark share the same accent colors.
--
-- PALETTE REFERENCE (Base colors):
--   base03       #002b36   (darkest - dark bg)
--   base02       #073642   (dark bg highlight)
--   base01       #586e75   (dark content, light emphasis)
--   base00       #657b83   (dark emphasis, light content)
--   base0        #839496   (dark content, light emphasis)
--   base1        #93a1a1   (dark emphasis, light content)
--   base2        #eee8d5   (light bg highlight)
--   base3        #fdf6e3   (lightest - light bg)
--
-- PALETTE REFERENCE (Accent colors - same in both modes):
--   yellow       #b58900   (warnings, modifications)
--   orange       #cb4b16   (constants, errors)
--   red          #dc322f   (errors, deletions)
--   magenta      #d33682   (optional emphasis)
--   violet       #6c71c4   (keywords, structure)
--   blue         #268bd2   (functions, links)
--   cyan         #2aa198   (types, classes)
--   green        #859900   (strings, additions)
--
-- USAGE NOTES:
--   Dark mode:  base03/base02 bg, base0/base1 fg
--   Light mode: base3/base2 bg, base00/base01 fg
--   The magic is that accent colors have equal contrast in both modes.

return {
  "maxmx03/solarized.nvim",
  name = "solarized",
  lazy = false,
  enabled = false, -- 👈 flip to true to activate
  priority = 1000,
  opts = {
    transparent = {
      enabled = false,
      pmenu = true,
      normal = false,
      normalfloat = false,
      neotree = false,
      nvimtree = false,
      whichkey = false,
      telescope = false,
      lazy = false,
    },
    on_highlights = function(colors, color)
      local hl = {}

      -- Telescope
      hl.TelescopeBorder = { fg = colors.base01, bg = colors.base03 }
      hl.TelescopePromptBorder = { fg = colors.base01, bg = colors.base02 }
      hl.TelescopePromptNormal = { bg = colors.base02 }
      hl.TelescopePromptTitle = { fg = colors.base03, bg = colors.blue, bold = true }
      hl.TelescopeResultsBorder = { fg = colors.base01, bg = colors.base03 }
      hl.TelescopeResultsNormal = { bg = colors.base03 }
      hl.TelescopePreviewBorder = { fg = colors.base01, bg = colors.base03 }
      hl.TelescopePreviewNormal = { bg = colors.base03 }
      hl.TelescopePreviewTitle = { fg = colors.base03, bg = colors.green, bold = true }
      hl.TelescopeSelection = { bg = colors.base02, bold = true }
      hl.TelescopeSelectionCaret = { fg = colors.cyan, bg = colors.base02 }

      -- Completion
      hl.CmpItemKindClass = { fg = colors.yellow }
      hl.CmpItemKindInterface = { fg = colors.cyan }
      hl.CmpItemKindFunction = { fg = colors.blue }
      hl.CmpItemKindMethod = { fg = colors.blue }
      hl.CmpItemKindVariable = { fg = colors.magenta }
      hl.CmpItemKindField = { fg = colors.cyan }
      hl.CmpItemKindProperty = { fg = colors.cyan }
      hl.CmpItemKindConstant = { fg = colors.orange }
      hl.CmpItemKindKeyword = { fg = colors.violet }
      hl.CmpItemKindSnippet = { fg = colors.green }
      hl.CmpItemKindText = { fg = colors.base0 }

      -- Git signs
      hl.GitSignsAdd = { fg = colors.green }
      hl.GitSignsChange = { fg = colors.yellow }
      hl.GitSignsDelete = { fg = colors.red }

      return hl
    end,
    on_colors = function(colors, color)
      return {}
    end,
    palette = "solarized", -- solarized or selenized
    variant = "autumn", -- spring, summer, autumn, winter (subtle tweaks)
    error_lens = {
      text = false,
      symbol = false,
    },
    styles = {
      comments = { italic = true },
      functions = {},
      variables = {},
      numbers = {},
      constants = {},
      parameters = {},
      keywords = {},
      types = {},
    },
    plugins = {
      treesitter = true,
      lspconfig = true,
      navic = true,
      cmp = true,
      indentblankline = true,
      neotree = true,
      nvimtree = true,
      whichkey = true,
      dashboard = true,
      gitsigns = true,
      telescope = true,
      noice = true,
      hop = true,
      ministatusline = true,
      minitabline = true,
      ministarter = true,
      minicursorword = true,
      notify = true,
      rainbowdelimiters = true,
      bufferline = true,
      lazy = true,
      rendermarkdown = true,
      ale = true,
      coc = true,
      leap = true,
      alpha = true,
      yanky = true,
      gitgutter = true,
      mason = true,
      flash = true,
    },
  },
  config = function(_, opts)
    vim.o.background = "dark" -- or "light"
    require("solarized").setup(opts)
    vim.cmd.colorscheme("solarized")
  end,
}
