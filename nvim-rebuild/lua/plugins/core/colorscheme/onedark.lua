-- plugins/core/colorscheme/onedark.lua
-- One Dark — Atom editor classic, balanced. The gateway drug to dark themes.
-- Multiple styles: dark, darker, cool, deep, warm, warmer, light
--
-- PALETTE REFERENCE (Dark style):
--   bg0          #282c34   (main bg)
--   bg1          #31353f   (elevated bg)
--   bg2          #393f4a   (selection bg)
--   bg3          #3b3f4c   (visual bg)
--   bg_d         #21252b   (darker bg)
--   bg_blue      #73b8f1   (blue bg accent)
--   bg_yellow    #ebd09c   (yellow bg accent)
--   fg           #abb2bf   (main text)
--   purple       #c678dd   (purple - keywords, imports)
--   green        #98c379   (green - strings)
--   orange       #d19a66   (orange - numbers, constants)
--   blue         #61afef   (blue - functions)
--   yellow       #e5c07b   (yellow - classes, types)
--   cyan         #56b6c2   (cyan - operators, regex)
--   red          #e86671   (red - errors, html tags)
--   grey         #5c6370   (gray - comments)
--   light_grey   #848b98   (light gray)
--   dark_cyan    #2b6f77   (dark cyan)
--   dark_red     #993939   (dark red)
--   dark_yellow  #93691d   (dark yellow)
--   dark_purple  #8a3fa0   (dark purple)
--   diff_add     #31392b   (diff add bg)
--   diff_delete  #382b2c   (diff delete bg)
--   diff_change  #1c3448   (diff change bg)
--   diff_text    #2c5372   (diff text bg)

return {
  "navarasu/onedark.nvim",
  name = "onedark",
  lazy = false,
  enabled = false, -- 👈 flip to true to activate
  priority = 1000,
  opts = {
    style = "dark", -- dark, darker, cool, deep, warm, warmer, light
    transparent = false,
    term_colors = true,
    ending_tildes = false,
    cmp_itemkind_reverse = false,

    toggle_style_key = nil,
    toggle_style_list = { "dark", "darker", "cool", "deep", "warm", "warmer", "light" },

    code_style = {
      comments = "italic",
      keywords = "none",
      functions = "none",
      strings = "none",
      variables = "none",
    },

    lualine = {
      transparent = false,
    },

    colors = {},
    highlights = {
      -- Telescope
      TelescopeBorder = { fg = "$grey", bg = "$bg0" },
      TelescopePromptBorder = { fg = "$grey", bg = "$bg1" },
      TelescopePromptNormal = { bg = "$bg1" },
      TelescopeResultsBorder = { fg = "$grey", bg = "$bg0" },
      TelescopeResultsNormal = { bg = "$bg0" },
      TelescopePreviewBorder = { fg = "$grey", bg = "$bg0" },
      TelescopePreviewNormal = { bg = "$bg0" },
      TelescopeSelection = { bg = "$bg2", bold = true },
      TelescopeSelectionCaret = { fg = "$blue", bg = "$bg2" },

      -- Completion
      CmpItemKindClass = { fg = "$yellow" },
      CmpItemKindInterface = { fg = "$cyan" },
      CmpItemKindFunction = { fg = "$blue" },
      CmpItemKindMethod = { fg = "$blue" },
      CmpItemKindVariable = { fg = "$red" },
      CmpItemKindField = { fg = "$cyan" },
      CmpItemKindProperty = { fg = "$cyan" },
      CmpItemKindConstant = { fg = "$orange" },
      CmpItemKindKeyword = { fg = "$purple" },
      CmpItemKindSnippet = { fg = "$green" },
      CmpItemKindText = { fg = "$fg" },

      -- Git signs
      GitSignsAdd = { fg = "$green" },
      GitSignsChange = { fg = "$yellow" },
      GitSignsDelete = { fg = "$red" },
    },

    diagnostics = {
      darker = true,
      undercurl = true,
      background = true,
    },
  },
  config = function(_, opts)
    require("onedark").setup(opts)
    require("onedark").load()
  end,
}
