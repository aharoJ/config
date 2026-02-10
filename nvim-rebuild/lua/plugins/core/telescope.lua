-- path: nvim-rebuild/lua/plugins/core/telescope.lua

local find_files_opts = {
    -- STRATEGY
    layout_strategy = "center",

    -- CONFIG
    layout_config = {
        width = 0.4,
        height = 0.35,
    },

    -- COSMETICS
    previewer = false,
    border = false,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

return {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        { "<leader>gf", function() local opts = type(find_files_opts) == "function" and find_files_opts() or find_files_opts require("telescope.builtin").find_files(opts) end, desc = "[get] file", },
    },
    config = function()
        require("telescope").setup({
            defaults = {
                prompt_prefix = "  ",
                selection_caret = "  ",
                entry_prefix = "   ",
                sorting_strategy = "ascending",
                file_ignore_patterns = { "node_modules", ".git/" },
            },
        })
    end,
}

