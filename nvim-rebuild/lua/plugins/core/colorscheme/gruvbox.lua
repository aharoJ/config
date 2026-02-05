-- plugins/core/colorscheme/gruvbox.lua
-- Gruvbox — The OG. Retro, warm, brownish. Been around forever, still slaps.
-- Two contrast modes: hard, soft. Dark and light variants.
--
-- PALETTE REFERENCE (Dark mode):
--   bg0_h        #1d2021   (hard contrast bg)
--   bg0          #282828   (main bg)
--   bg0_s        #32302f   (soft contrast bg)
--   bg1          #3c3836   (lighter bg)
--   bg2          #504945   (selection bg)
--   bg3          #665c54   (visual bg)
--   bg4          #7c6f64   (border)
--   fg0          #fbf1c7   (bright text)
--   fg1          #ebdbb2   (main text)
--   fg2          #d5c4a1   (secondary text)
--   fg3          #bdae93   (tertiary text)
--   fg4          #a89984   (dark text)
--   gray         #928374   (gray - comments)
--   red          #cc241d   (dark red)
--   red_bright   #fb4934   (bright red - errors)
--   green        #98971a   (dark green)
--   green_bright #b8bb26   (bright green - strings)
--   yellow       #d79921   (dark yellow)
--   yellow_bright #fabd2f   (bright yellow - warnings)
--   blue         #458588   (dark blue)
--   blue_bright  #83a598   (bright blue - functions)
--   purple       #b16286   (dark purple)
--   purple_bright #d3869b  (bright purple - keywords)
--   aqua         #689d6a   (dark aqua)
--   aqua_bright  #8ec07c   (bright aqua)
--   orange       #d65d0e   (dark orange)
--   orange_bright #fe8019  (bright orange)

return {
  "ellisonleao/gruvbox.nvim",
  name = "gruvbox",
  lazy = false,
  enabled = false, -- 👈 flip to true to activate
  priority = 1000,
  opts = {
    terminal_colors = true,
    undercurl = true,
    underline = true,
    bold = true,
    italic = {
      strings = true,
      emphasis = true,
      comments = true,
      operators = false,
      folds = true,
    },
    strikethrough = true,
    invert_selection = false,
    invert_signs = false,
    invert_tabline = false,
    invert_intend_guides = false,
    inverse = true,
    contrast = "", -- "hard", "soft", or "" (medium)
    palette_overrides = {},
    overrides = {},
    dim_inactive = false,
    transparent_mode = false,
  },
  config = function(_, opts)
    require("gruvbox").setup(opts)

    -- Set background before colorscheme
    vim.o.background = "dark"
    vim.cmd.colorscheme("gruvbox")

    -- Custom overrides after load
    local hl = vim.api.nvim_set_hl

    -- Telescope
    hl(0, "TelescopeBorder", { link = "GruvboxBg2" })
    hl(0, "TelescopePromptBorder", { link = "GruvboxBg2" })
    hl(0, "TelescopeResultsBorder", { link = "GruvboxBg2" })
    hl(0, "TelescopePreviewBorder", { link = "GruvboxBg2" })
    hl(0, "TelescopeSelection", { bg = "#3c3836", bold = true })
    hl(0, "TelescopeSelectionCaret", { fg = "#fb4934", bg = "#3c3836" })

    -- Completion (gruvbox-themed)
    hl(0, "CmpItemKindClass", { fg = "#fabd2f" }) -- yellow
    hl(0, "CmpItemKindInterface", { fg = "#83a598" }) -- blue
    hl(0, "CmpItemKindFunction", { fg = "#d3869b" }) -- purple
    hl(0, "CmpItemKindMethod", { fg = "#d3869b" }) -- purple
    hl(0, "CmpItemKindVariable", { fg = "#83a598" }) -- blue
    hl(0, "CmpItemKindField", { fg = "#8ec07c" }) -- aqua
    hl(0, "CmpItemKindProperty", { fg = "#8ec07c" }) -- aqua
    hl(0, "CmpItemKindConstant", { fg = "#fe8019" }) -- orange
    hl(0, "CmpItemKindKeyword", { fg = "#fb4934" }) -- red
    hl(0, "CmpItemKindSnippet", { fg = "#b8bb26" }) -- green
    hl(0, "CmpItemKindText", { fg = "#ebdbb2" }) -- fg

    -- Git signs
    hl(0, "GitSignsAdd", { fg = "#b8bb26" })
    hl(0, "GitSignsChange", { fg = "#fabd2f" })
    hl(0, "GitSignsDelete", { fg = "#fb4934" })
  end,
}
