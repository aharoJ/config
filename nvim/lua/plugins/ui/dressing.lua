return {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {
        input = { relative = "cursor" },
        select = {
            backend = { "builtin" }, -- simple, fast
            builtin = { border = "rounded" },
        },
    },
}
