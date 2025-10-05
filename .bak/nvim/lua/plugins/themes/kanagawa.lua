-- path: nvim/lua/plugins/themes/kanagawa.lua
return {
    "rebelot/kanagawa.nvim",
    config = function()
        vim.cmd.colorscheme("kanagawa-wave")
    end,
}