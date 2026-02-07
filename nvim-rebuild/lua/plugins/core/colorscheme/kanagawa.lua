-- plugins/colorscheme/kanagawa.lua
-- Kanagawa — Japanese ink painting aesthetic
-- Warm, muted, sophisticated. Matches your CVMApp cream/moss/burgundy palette.

return {
  "rebelot/kanagawa.nvim",
  name = "kanagawa",
  enabled= true,
  lazy = false,
  priority = 1000,
  opts = {
    compile = false,
    undercurl = true,
    commentStyle = { italic = true },
    functionStyle = {},
    keywordStyle = { italic = true },
    statementStyle = { bold = true },
    typeStyle = {},
    transparent = false,
    dimInactive = false,
    terminalColors = true,
    theme = "wave", -- wave (dark), dragon (darker), lotus (light)
    background = {
      dark = "wave",
      light = "lotus",
    },
    colors = {
      theme = {
        all = {
          ui = {
            bg_gutter = "none", -- cleaner gutter
          },
        },
      },
    },
    overrides = function(colors)
      local theme = colors.theme
      return {
        -- Cleaner floats (telescope, cmp, etc.)
        NormalFloat = { bg = theme.ui.bg_p1 },
        FloatBorder = { bg = theme.ui.bg_p1, fg = theme.ui.shade0 },
        FloatTitle = { bg = theme.ui.bg_p1, fg = theme.ui.special, bold = true },

        -- Telescope
        TelescopeTitle = { fg = theme.ui.special, bold = true },
        TelescopePromptNormal = { bg = theme.ui.bg_p1 },
        TelescopePromptBorder = { bg = theme.ui.bg_p1, fg = theme.ui.bg_p1 },
        TelescopeResultsNormal = { bg = theme.ui.bg_m1 },
        TelescopeResultsBorder = { bg = theme.ui.bg_m1, fg = theme.ui.bg_m1 },
        TelescopePreviewNormal = { bg = theme.ui.bg_dim },
        TelescopePreviewBorder = { bg = theme.ui.bg_dim, fg = theme.ui.bg_dim },

        -- Completion menu
        Pmenu = { fg = theme.ui.shade0, bg = theme.ui.bg_p1 },
        PmenuSel = { fg = "NONE", bg = theme.ui.bg_p2 },
        PmenuSbar = { bg = theme.ui.bg_m1 },
        PmenuThumb = { bg = theme.ui.bg_p2 },

        -- Cleaner diagnostics
        DiagnosticVirtualTextError = { fg = colors.palette.samuraiRed, bg = "NONE" },
        DiagnosticVirtualTextWarn = { fg = colors.palette.roninYellow, bg = "NONE" },
        DiagnosticVirtualTextInfo = { fg = colors.palette.waveAqua1, bg = "NONE" },
        DiagnosticVirtualTextHint = { fg = colors.palette.dragonBlue, bg = "NONE" },
      }
    end,
  },
  config = function(_, opts)
    require("kanagawa").setup(opts)
    vim.cmd.colorscheme("kanagawa")
  end,
}
