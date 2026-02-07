-- plugins/core/colorscheme/nord.lua
-- Nord — Arctic, icy blues, very clean. Scandinavian minimalism.
-- The "professional" choice. Great for presentations.
--
-- PALETTE REFERENCE (Polar Night - backgrounds):
--   nord0        #2e3440   (main bg - darkest)
--   nord1        #3b4252   (elevated bg)
--   nord2        #434c5e   (selection bg)
--   nord3        #4c566a   (comments, invisibles)
--
-- PALETTE REFERENCE (Snow Storm - text):
--   nord4        #d8dee9   (main text)
--   nord5        #e5e9f0   (secondary text, lighter)
--   nord6        #eceff4   (bright text, lightest)
--
-- PALETTE REFERENCE (Frost - accent blues):
--   nord7        #8fbcbb   (teal - classes, types)
--   nord8        #88c0d0   (cyan - declarations, functions)
--   nord9        #81a1c1   (light blue - keywords)
--   nord10       #5e81ac   (dark blue - pragmas)
--
-- PALETTE REFERENCE (Aurora - accent colors):
--   nord11       #bf616a   (red - errors, deletions)
--   nord12       #d08770   (orange - warnings, escape chars)
--   nord13       #ebcb8b   (yellow - strings, warnings)
--   nord14       #a3be8c   (green - strings, additions)
--   nord15       #b48ead   (purple - numbers, annotations)

return {
  "shaunsingh/nord.nvim",
  name = "nord",
  lazy = false,
  enabled = false, -- 👈 flip to true to activate
  priority = 1000,
  config = function()
    -- Nord settings (must be set before colorscheme)
    vim.g.nord_contrast = true
    vim.g.nord_borders = true
    vim.g.nord_disable_background = false
    vim.g.nord_italic = true
    vim.g.nord_uniform_diff_background = true
    vim.g.nord_bold = true

    require("nord").set()

    -- Custom overrides after load
    local hl = vim.api.nvim_set_hl

    -- Telescope (clean nord style)
    hl(0, "TelescopeBorder", { fg = "#4c566a", bg = "#2e3440" })
    hl(0, "TelescopePromptBorder", { fg = "#4c566a", bg = "#2e3440" })
    hl(0, "TelescopeResultsBorder", { fg = "#4c566a", bg = "#2e3440" })
    hl(0, "TelescopePreviewBorder", { fg = "#4c566a", bg = "#2e3440" })
    hl(0, "TelescopePromptNormal", { bg = "#3b4252" })
    hl(0, "TelescopeResultsNormal", { bg = "#2e3440" })
    hl(0, "TelescopePreviewNormal", { bg = "#2e3440" })
    hl(0, "TelescopeSelection", { bg = "#434c5e", bold = true })
    hl(0, "TelescopeSelectionCaret", { fg = "#88c0d0", bg = "#434c5e" })

    -- Completion (nord-themed)
    hl(0, "CmpItemKindClass", { fg = "#8fbcbb" }) -- nord7 teal
    hl(0, "CmpItemKindInterface", { fg = "#88c0d0" }) -- nord8 cyan
    hl(0, "CmpItemKindFunction", { fg = "#88c0d0" }) -- nord8 cyan
    hl(0, "CmpItemKindMethod", { fg = "#88c0d0" }) -- nord8 cyan
    hl(0, "CmpItemKindVariable", { fg = "#d8dee9" }) -- nord4 text
    hl(0, "CmpItemKindField", { fg = "#8fbcbb" }) -- nord7 teal
    hl(0, "CmpItemKindProperty", { fg = "#8fbcbb" }) -- nord7 teal
    hl(0, "CmpItemKindConstant", { fg = "#b48ead" }) -- nord15 purple
    hl(0, "CmpItemKindKeyword", { fg = "#81a1c1" }) -- nord9 blue
    hl(0, "CmpItemKindSnippet", { fg = "#a3be8c" }) -- nord14 green
    hl(0, "CmpItemKindText", { fg = "#d8dee9" }) -- nord4 text

    -- Git signs (aurora colors)
    hl(0, "GitSignsAdd", { fg = "#a3be8c" }) -- nord14 green
    hl(0, "GitSignsChange", { fg = "#ebcb8b" }) -- nord13 yellow
    hl(0, "GitSignsDelete", { fg = "#bf616a" }) -- nord11 red
  end,
}
