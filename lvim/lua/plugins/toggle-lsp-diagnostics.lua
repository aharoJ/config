vim.api.nvim_set_keymap('n', '<leader>zt', ':ToggleDiag<CR>', { noremap = true, silent = true })


require('toggle_lsp_diagnostics').init()
