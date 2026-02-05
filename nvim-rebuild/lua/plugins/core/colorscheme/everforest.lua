-- plugins/colorscheme/everforest.lua
-- Everforest — Nature-inspired, calming greens
-- Matches your CVMApp soft-moss aesthetic. Gentle on the eyes for long sessions.

return {
  "sainnhe/everforest",
  name = "everforest",
  enabled= false,
  lazy = false,
  priority = 1000,
  config = function()
    -- Must set these BEFORE colorscheme loads
    vim.g.everforest_background = "medium" -- hard, medium, soft
    vim.g.everforest_better_performance = 1
    vim.g.everforest_enable_italic = 1
    vim.g.everforest_disable_italic_comment = 0
    vim.g.everforest_cursor = "auto"
    vim.g.everforest_transparent_background = 0
    vim.g.everforest_dim_inactive_windows = 0
    vim.g.everforest_ui_contrast = "low" -- low, high
    vim.g.everforest_show_eob = 1
    vim.g.everforest_float_style = "bright" -- bright, dim
    vim.g.everforest_diagnostic_text_highlight = 0
    vim.g.everforest_diagnostic_line_highlight = 0
    vim.g.everforest_diagnostic_virtual_text = "colored" -- grey, colored, highlighted

    vim.cmd.colorscheme("everforest")

    -- Custom overrides after theme loads
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "everforest",
      callback = function()
        local hl = vim.api.nvim_set_hl

        -- Cleaner telescope
        hl(0, "TelescopeBorder", { link = "FloatBorder" })
        hl(0, "TelescopePromptBorder", { link = "FloatBorder" })
        hl(0, "TelescopeResultsBorder", { link = "FloatBorder" })
        hl(0, "TelescopePreviewBorder", { link = "FloatBorder" })

        -- Subtle selection
        hl(0, "TelescopeSelection", { bg = "#3a4248", bold = true })

        -- Git signs colors (forest-themed)
        hl(0, "GitSignsAdd", { fg = "#a7c080" })
        hl(0, "GitSignsChange", { fg = "#dbbc7f" })
        hl(0, "GitSignsDelete", { fg = "#e67e80" })
      end,
    })
  end,
}
