-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny
vim.opt.shell = "/bin/sh"
vim.g.mapleader = " "
-- lvim.lsp.automatic_servers_installation = false


----------------    PLUGINS    ----------------
require('plugins.ALL')
require('plugins.lf')
require('plugins.toggle-lsp-diagnostics')
----------------               ----------------

----------------    SCRIPTS    ----------------
require('scripts.folding')
require('scripts.run_java')
----------------               ----------------


-- Key mappings
lvim.keys.normal_mode = {
  ["<C-d>"] = "<C-d>zz", -- Scroll down half a page and center the line
  ["<C-u>"] = "<C-u>zz", -- Scroll up half a page and center the line
}


lvim.colorscheme = "catppuccin-mocha"
--lvim.colorscheme = "rose-pine-main"

lvim.transparent_window = true

vim.opt.wrap = true                    -- wrap lines
vim.opt.relativenumber = true          -- relative line numbers
-- vim.opt.guifont = "monospace:h17"      -- the font used in graphical neovim applications
vim.opt.tabstop = 2                    -- insert 4 spaces for a tab
vim.opt.shiftwidth = 2                 -- the number of spaces inserted for each indentation

lvim.builtin.lualine.style = "default" -- or "none"

-- vim.opt.hlsearch= false
-- vim.opt.incsearch= true
-- vim.opt.termguicolors = true
-- vim.opt.scrolloff = 2
-- vim.opt.signcolumn = "yes"
--vim.opt.isfname: append ("@-@")
--vim.opt.updatetime = 50


lvim.format_on_save.enabled = true

-- So we can Use <up> <down> instead of tab cycle
vim.api.nvim_set_keymap('c', '<Up>', '<C-p>', { noremap = true })
vim.api.nvim_set_keymap('c', '<Down>', '<C-n>', { noremap = true })

-- my own which key map "z"
lvim.builtin.which_key.mappings["z"] = { name = "aharoJ" }

-- removes the which_key = which is the mini map thingt
lvim.builtin.which_key.mappings['c'] = {}

-- bind the command + Close Buffer
lvim.builtin.which_key.mappings["b"]["c"] = { ":bd<CR>", "Close Buffer" }

-- require('nvim-tree.view').resize(40)

-- vim.o.scrolloff = 5   -- This sets a 5-line margin at the top and bottom.
vim.opt.cmdheight = 0 -- this is the little bar at the bottom


-- greatest remap ever
lvim.keys.visual_mode["<leader>p"] = '"_dp'

-- next greatest remap ever : asbjornHaland
lvim.keys.normal_mode["<leader>y"] = '"+y'
lvim.keys.visual_mode["<leader>y"] = '"+y'
lvim.keys.normal_mode["<leader>d"] = '"_d'
lvim.keys.visual_mode["<leader>d"] = '"_d'
lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"




-- -- Vimscript wrapped inside Lua
-- vim.cmd [[
-- function! CompileAndRunJavaPackage()
--     let l:current_file = expand('%')
--     let l:package_directory = expand('%:p:h')
--     let l:parent_directory = fnamemodify(l:package_directory, ':h')
--     execute '!javac ' . l:package_directory . '/*.java'
--     let l:package_name = substitute(l:package_directory, l:parent_directory.'/', '', '')
--     let l:package_name = substitute(l:package_name, '/', '.', 'g')
--     let l:class_name = fnamemodify(l:current_file, ':t:r')
--     let l:full_class = l:package_name . '.' . l:class_name
--     execute '!java -cp ' . l:parent_directory . ' ' . l:full_class
-- endfunction
-- ]]

-- Lua keymap for Ctrl+r
-- vim.api.nvim_set_keymap('n', '<Space>r', ':call CompileAndRunJavaPackage()<CR>', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', '<C-r>', ':call CompileAndRunJavaPackage()<CR>', { noremap = true, silent = true })

-- vim.api.nvim_set_keymap('n', '<Space>r', ':w!<CR>:10split | terminal javac % && java %<CR>',
--   { noremap = true, silent = true })



-- vim.cmd [[
--   highlight Folded guibg=grey guifg=blue
--   highlight FoldColumn guibg=darkgrey guifg=white
-- ]]

-- vim.opt.foldtext = [[v:lua.MyFoldText()]]
-- function _G.MyFoldText()
--   local line = vim.fn.getline(vim.v.foldstart)
--   local sub = vim.fn.substitute(line, "/\\*\\|\\*/\\|{{{{\\d\\=", "", "g")
--   return vim.v.folddashes .. sub
-- end

-- vim.opt.foldcolumn = "auto:9"
