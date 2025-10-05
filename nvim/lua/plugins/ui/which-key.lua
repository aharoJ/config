-- -- path: vim/lua/plugins/ui/which-key.lua

-- return {
--   "folke/which-key.nvim",
--   event = "VeryLazy",
--   opts = {
--     -- your configuration comes here
--     -- or leave it empty to use the default settings
--     -- refer to the configuration section below
--   },
--   keys = {
--     {
--       "<leader>?",
--       function()
--         require("which-key").show({ global = false })
--       end,
--       desc = "Buffer Local Keymaps (which-key)",
--     },
--   },
-- }


-- path: nvim/lua/plugins/ui/which-key.lua
return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = function()
        -- pull colors from Kanagawa so the tint matches your theme
        local K = require("kanagawa.colors").setup()
        local ui = K.theme.ui

        -- set highlight groups for tint + border
        vim.api.nvim_set_hl(0, "WhichKeyNormal", { bg = "none", fg = ui.fg }) -- slight tint
        vim.api.nvim_set_hl(0, "WhichKeyBorder", { bg = "none", fg = ui.fg_dim }) -- subtle border
        vim.api.nvim_set_hl(0, "WhichKeyTitle", { bg = "none", fg = ui.special, bold = true })

        return {
            win = {
                border = "rounded", -- "single" | "double" | "rounded" | "solid" | "shadow" | ...
                padding = { 1, 2 },
                title = true,
                title_pos = "center",
                zindex = 1000,
                wo = {
                    -- small blend to let the terminal peek through a bit
                    winblend = 0, -- 0 = solid, 100 = fully transparent
                },
            },
            layout = {
                width = { min = 24 },
                spacing = 3,
            },
            icons = { mappings = false },
        }
    end,
    keys = {
        { "<leader>?", function() 	require("which-key").show({ global = false }) end, desc = "Buffer Local Keymaps (which-key)", },
        -- { "gq", desc = "[internal][format] line" },
        -- { "gq", desc = "[internal][format] cursor" },

    },
}
