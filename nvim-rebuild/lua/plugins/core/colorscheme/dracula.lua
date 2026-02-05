-- plugins/core/colorscheme/dracula.lua
-- Dracula — Purple/cyan pop, very recognizable. The flashy choice.
-- High contrast, vibrant colors. You either love it or it's too much.
--
-- PALETTE REFERENCE:
--   background   #282a36   (main bg)
--   current_line #44475a   (cursor line, selection)
--   foreground   #f8f8f2   (main text)
--   comment      #6272a4   (comments - blueish gray)
--   cyan         #8be9fd   (cyan - classes, types)
--   green        #50fa7b   (green - strings)
--   orange       #ffb86c   (orange - numbers, constants)
--   pink         #ff79c6   (pink - keywords, operators)
--   purple       #bd93f9   (purple - functions, methods)
--   red          #ff5555   (red - errors, deletions)
--   yellow       #f1fa8c   (yellow - warnings, class names)
--
-- ANSI COLORS:
--   black        #21222c   (ansi black)
--   bright_black #6272a4   (ansi bright black)
--   white        #f8f8f2   (ansi white)
--   bright_white #ffffff   (ansi bright white)
--   bright_red   #ff6e6e   (ansi bright red)
--   bright_green #69ff94   (ansi bright green)
--   bright_yellow #ffffa5  (ansi bright yellow)
--   bright_blue  #d6acff   (ansi bright blue)
--   bright_magenta #ff92df (ansi bright magenta)
--   bright_cyan  #a4ffff   (ansi bright cyan)

return {
  "Mofiqul/dracula.nvim",
  name = "dracula",
  lazy = false,
  enabled = false, -- 👈 flip to true to activate
  priority = 1000,
  opts = {
    colors = {
      bg = "#282A36",
      fg = "#F8F8F2",
      selection = "#44475A",
      comment = "#6272A4",
      red = "#FF5555",
      orange = "#FFB86C",
      yellow = "#F1FA8C",
      green = "#50FA7B",
      purple = "#BD93F9",
      cyan = "#8BE9FD",
      pink = "#FF79C6",
      bright_red = "#FF6E6E",
      bright_green = "#69FF94",
      bright_yellow = "#FFFFA5",
      bright_blue = "#D6ACFF",
      bright_magenta = "#FF92DF",
      bright_cyan = "#A4FFFF",
      bright_white = "#FFFFFF",
      menu = "#21222C",
      visual = "#3E4452",
      gutter_fg = "#4B5263",
      nontext = "#3B4048",
      white = "#ABB2BF",
      black = "#191A21",
    },
    show_end_of_buffer = false,
    transparent_bg = false,
    lualine_bg_color = "#44475a",
    italic_comment = true,
    overrides = function(colors)
      return {
        -- Telescope
        TelescopeBorder = { fg = colors.comment, bg = colors.bg },
        TelescopePromptBorder = { fg = colors.comment, bg = colors.menu },
        TelescopePromptNormal = { bg = colors.menu },
        TelescopePromptTitle = { fg = colors.bg, bg = colors.purple, bold = true },
        TelescopeResultsBorder = { fg = colors.comment, bg = colors.bg },
        TelescopeResultsNormal = { bg = colors.bg },
        TelescopeResultsTitle = { fg = colors.bg, bg = colors.bg },
        TelescopePreviewBorder = { fg = colors.comment, bg = colors.bg },
        TelescopePreviewNormal = { bg = colors.bg },
        TelescopePreviewTitle = { fg = colors.bg, bg = colors.green, bold = true },
        TelescopeSelection = { bg = colors.selection, bold = true },
        TelescopeSelectionCaret = { fg = colors.cyan, bg = colors.selection },

        -- Completion (dracula-themed - vibrant)
        CmpItemKindClass = { fg = colors.yellow },
        CmpItemKindInterface = { fg = colors.cyan },
        CmpItemKindFunction = { fg = colors.purple },
        CmpItemKindMethod = { fg = colors.purple },
        CmpItemKindVariable = { fg = colors.pink },
        CmpItemKindField = { fg = colors.cyan },
        CmpItemKindProperty = { fg = colors.cyan },
        CmpItemKindConstant = { fg = colors.orange },
        CmpItemKindKeyword = { fg = colors.pink },
        CmpItemKindSnippet = { fg = colors.green },
        CmpItemKindText = { fg = colors.fg },
        CmpItemKindEnum = { fg = colors.yellow },
        CmpItemKindStruct = { fg = colors.yellow },
        CmpItemKindModule = { fg = colors.purple },

        -- Git signs (vibrant dracula style)
        GitSignsAdd = { fg = colors.green },
        GitSignsChange = { fg = colors.orange },
        GitSignsDelete = { fg = colors.red },

        -- Treesitter context
        TreesitterContext = { bg = colors.menu },
        TreesitterContextLineNumber = { fg = colors.comment, bg = colors.menu },
      }
    end,
  },
  config = function(_, opts)
    require("dracula").setup(opts)
    vim.cmd.colorscheme("dracula")
  end,
}
