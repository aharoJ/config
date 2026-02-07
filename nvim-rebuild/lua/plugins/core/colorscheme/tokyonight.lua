-- plugins/core/colorscheme/tokyonight.lua
-- Tokyo Night — The de facto modern dev standard
-- Deep blues, soft purples, excellent contrast. Three variants: night, storm, day.
--
-- PALETTE REFERENCE (Night variant):
--   bg           #1a1b26   (main bg)
--   bg_dark      #16161e   (darker bg)
--   bg_float     #16161e   (floating windows)
--   bg_highlight #292e42   (cursor line)
--   bg_popup     #16161e   (popup bg)
--   bg_search    #3d59a1   (search highlight)
--   bg_sidebar   #16161e   (sidebar bg)
--   bg_statusline #16161e  (statusline bg)
--   bg_visual    #283457   (visual selection)
--   black        #15161e   (terminal black)
--   blue         #7aa2f7   (blue - functions)
--   blue0        #3d59a1   (dark blue)
--   blue1        #2ac3de   (cyan blue)
--   blue2        #0db9d7   (bright cyan)
--   blue5        #89ddff   (light cyan)
--   blue6        #b4f9f8   (pale cyan)
--   blue7        #394b70   (muted blue)
--   comment      #565f89   (comments)
--   cyan         #7dcfff   (cyan)
--   dark3        #545c7e   (dark gray)
--   dark5        #737aa2   (medium gray)
--   fg           #c0caf5   (main text)
--   fg_dark      #a9b1d6   (secondary text)
--   fg_float     #c0caf5   (float text)
--   fg_gutter    #3b4261   (gutter text)
--   fg_sidebar   #a9b1d6   (sidebar text)
--   green        #9ece6a   (green - strings)
--   green1       #73daca   (teal green)
--   green2       #41a6b5   (dark teal)
--   magenta      #bb9af7   (purple - keywords)
--   magenta2     #ff007c   (bright magenta)
--   orange       #ff9e64   (orange)
--   purple       #9d7cd8   (purple)
--   red          #f7768e   (red - errors)
--   red1         #db4b4b   (dark red)
--   teal         #1abc9c   (teal)
--   terminal_black #414868 (terminal black)
--   yellow       #e0af68   (yellow - warnings)

return {
  "folke/tokyonight.nvim",
  name = "tokyonight",
  lazy = false,
  enabled = false, -- 👈 flip to true to activate
  priority = 1000,
  opts = {
    style = "night", -- night, storm, day, moon
    light_style = "day",
    transparent = false,
    terminal_colors = true,
    styles = {
      comments = { italic = true },
      keywords = { italic = true },
      functions = {},
      variables = {},
      sidebars = "dark",
      floats = "dark",
    },
    sidebars = { "qf", "help", "terminal", "packer", "neo-tree" },
    day_brightness = 0.3,
    hide_inactive_statusline = false,
    dim_inactive = false,
    lualine_bold = false,

    on_colors = function(colors)
      -- Custom color overrides here if needed
      -- colors.hint = colors.orange
      -- colors.error = "#ff0000"
    end,

    on_highlights = function(hl, colors)
      -- Telescope (borderless style)
      hl.TelescopeNormal = { bg = colors.bg_dark, fg = colors.fg_dark }
      hl.TelescopeBorder = { bg = colors.bg_dark, fg = colors.bg_dark }
      hl.TelescopePromptNormal = { bg = colors.bg_highlight }
      hl.TelescopePromptBorder = { bg = colors.bg_highlight, fg = colors.bg_highlight }
      hl.TelescopePromptTitle = { bg = colors.blue, fg = colors.bg_dark, bold = true }
      hl.TelescopeResultsNormal = { bg = colors.bg_dark }
      hl.TelescopeResultsBorder = { bg = colors.bg_dark, fg = colors.bg_dark }
      hl.TelescopeResultsTitle = { bg = colors.bg_dark, fg = colors.bg_dark }
      hl.TelescopePreviewNormal = { bg = colors.bg_dark }
      hl.TelescopePreviewBorder = { bg = colors.bg_dark, fg = colors.bg_dark }
      hl.TelescopePreviewTitle = { bg = colors.green, fg = colors.bg_dark, bold = true }

      -- Completion
      hl.CmpItemKindClass = { fg = colors.orange }
      hl.CmpItemKindInterface = { fg = colors.cyan }
      hl.CmpItemKindFunction = { fg = colors.blue }
      hl.CmpItemKindMethod = { fg = colors.blue }
      hl.CmpItemKindVariable = { fg = colors.magenta }
      hl.CmpItemKindKeyword = { fg = colors.red }
      hl.CmpItemKindSnippet = { fg = colors.green }
      hl.CmpItemKindText = { fg = colors.fg_dark }

      -- Git signs
      hl.GitSignsAdd = { fg = colors.green }
      hl.GitSignsChange = { fg = colors.yellow }
      hl.GitSignsDelete = { fg = colors.red }
    end,
  },
  config = function(_, opts)
    require("tokyonight").setup(opts)
    vim.cmd.colorscheme("tokyonight")
  end,
}
