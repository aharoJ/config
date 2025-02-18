return {
    "WhoIsSethDaniel/toggle-lsp-diagnostics.nvim",
    config = function()
        require("toggle_lsp_diagnostics").init()
        vim.api.nvim_set_keymap("n", "<leader>tl", "<Plug>(toggle-lsp-diag)", { noremap = true, silent = true })
        -- vim.api.nvim_set_keymap('n', '<leader>ctu', '<Plug>(toggle-lsp-diag-underline)', { noremap = true, silent = true })
        -- vim.api.nvim_set_keymap('n', '<leader>cts', '<Plug>(toggle-lsp-diag-signs)', { noremap = true, silent = true })
        -- vim.api.nvim_set_keymap('n', '<leader>ctv', '<Plug>(toggle-lsp-diag-vtext)', { noremap = true, silent = true })
        -- vim.api.nvim_set_keymap('n', '<leader>ctp', '<Plug>(toggle-lsp-diag-update_in_insert)', { noremap = true, silent = true })
        -- vim.api.nvim_set_keymap('n', '<leader>tldd', '<Plug>(toggle-lsp-diag-default)', { noremap = true, silent = true })
    end,
}
