---@diagnostic disable: undefined-global, undefined-doc-name
---@type LazySpec

return {
    "mikavilpas/yazi.nvim",
    keys = {
        { "<leader>e",  "<cmd>Yazi<cr>" },
        -- { "<leader>cw", "<cmd>Yazi cwd<cr>",    desc = "Yazi (at CWD)" },
        -- { "<C-Up>",     "<cmd>Yazi toggle<cr>", desc = "Yazi resume" },
    },
    cmd = { "Yazi" },
    opts = {},
}
