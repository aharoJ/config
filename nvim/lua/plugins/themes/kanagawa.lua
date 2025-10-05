-- path: nvim/lua/plugins/themes/kanagawa.lua
return {
    "rebelot/kanagawa.nvim",
    config = function()
        require("kanagawa").setup({
            compile = false,     -- optional, set to true if you want bytecode compilation
            transparent = true,  -- 🔑 makes background fully transparent
            dimInactive = false, -- keep inactive splits the same
            terminalColors = true,
            colors = {
                theme = {
                    all = {
                        ui = {
                            bg_gutter = "none", -- remove background from line numbers/sign column
                        },
                    },
                },
            },
            overrides = function(colors)
                local theme = colors.theme
                return {
                    NormalFloat = { bg = "none" },
                    FloatBorder = { bg = "none" },
                    FloatTitle = { bg = "none" },
                    -- Optional: darken Lazy/Mason floating windows slightly instead of fully transparent
                    LazyNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
                    MasonNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
                }
            end,
        })

        -- load AFTER setup
        vim.cmd.colorscheme("kanagawa-wave")
    end,
}
