-------------------    LF PLUG ------------------------
-- vim.g.lf_map_keys = 0
-- lvim.keys.normal_mode["<leader>zl"] = ":Lf<CR>"
-- lvim.keys.normal_mode["<leader>zl"] = ":LfCurrentDirectory<CR>"
vim.api.nvim_set_keymap('n', '<leader>zl', ':LfWorkingDirectory<CR>', { noremap = true, silent = true })
vim.g.lf_width = 380 -- This sets the width
vim.g.lf_height = 30 -- This sets the height

-- vim.g.NERDTreeHijackNetrw = 0
-- vim.g.lf_replace_netrw = 1
-- vim.g.lf_command_override = 'lf -command "set hidden"'
-- let g:lf_command_override = 'lf -command "set hidden"'
-- let g:NERDTreeHijackNetrw = 0 " Add this line if you use NERDTree
-- let g:lf_replace_netrw = 1 " Open lf when vim opens a directory
------------------------------------------------------
