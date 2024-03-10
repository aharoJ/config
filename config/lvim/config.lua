-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny
vim.opt.shell = "/bin/sh"
vim.g.mapleader = " "
lvim.lsp.automatic_servers_installation = false


-- Plugins
lvim.plugins = {
  -- theme --
  { "catppuccin/nvim",         name = "catppuccin", priority = 1000 },
  { "rose-pine/neovim",        name = "rose-pine" },
  --     ...............            --

  -- the goat  --
  { "ThePrimeagen/vim-be-good" }, -- vim-be-good plugin
  --     ...............            --

  { "mfussenegger/nvim-jdtls" },
  { "williamboman/mason.nvim" },

  -- DAP STUFF --
  -- { "ldelossa/nvim-dap-projects" },
  -- { "mfussenegger/nvim-dap" },
  -- { "rcarriga/nvim-dap-ui" },
  -- { "theHamsta/nvim-dap-virtual-text" },
  -- { "neovim/nvim-lspconfig" },
  -- { "rcarriga/cmp-dap" },
  --     ...............            --

  -- lf plug  --
  { "ptzz/lf.vim" },
  { "voldikss/vim-floaterm" },
  --     ...............            --
}

-- Key mappings
lvim.keys.normal_mode = {
  ["<C-d>"] = "<C-d>zz", -- Scroll down half a page and center the line
  ["<C-u>"] = "<C-u>zz", -- Scroll up half a page and center the line
}

-- greatest remap ever
lvim.keys.visual_mode["<leader>p"] = '"_dp'

-- next greatest remap ever : asbjornHaland
lvim.keys.normal_mode["<leader>y"] = '"+y'
lvim.keys.visual_mode["<leader>y"] = '"+y'
lvim.keys.normal_mode["<leader>d"] = '"_d'
lvim.keys.visual_mode["<leader>d"] = '"_d'

lvim.colorscheme = "catppuccin-mocha"
--lvim.colorscheme = "rose-pine-main"

lvim.transparent_window = true

vim.opt.wrap = true           -- wrap lines
vim.opt.relativenumber = true -- relative line numbers
--vim.opt.cmdheight = 2 -- more space in the neovim command line for displaying messages
-- vim.opt.guifont = "monospace:h17" -- the font used in graphical neovim applications
vim.opt.tabstop = 2                    -- insert 4 spaces for a tab
vim.opt.shiftwidth = 2                 -- the number of spaces inserted for each indentation

lvim.builtin.lualine.style = "default" -- or "none"

-- vim.opt.hlsearch= false
-- vim.opt.incsearch= true
-- vim.opt.termguicolors = true
-- vim.opt.scrolloff = 8
-- vim.opt.signcolumn = "yes"
--vim.opt.isfname: append ("@-@")
--vim.opt.updatetime = 50

-- vim.api.nvim_set_keymap('n', '<leader>r', ':w!<CR>:!javac % && java %<CR>', { noremap = true, silent = true })

-- vim.api.nvim_set_keymap('n', '<Space>r', ':w!<CR>:!javac % && echo "" && echo "OUTPUT:" && java %<CR>', { noremap = true, silent = true })

-- vim.api.nvim_set_keymap('n', '<Space>r', ':w!<CR>:split | terminal javac % && java %<CR>', { noremap = true, silent = true })

vim.api.nvim_set_keymap('n', '<Space>r', ':w!<CR>:10split | terminal javac % && java %<CR>',
  { noremap = true, silent = true })

lvim.format_on_save.enabled = true

-- vim.api.nvim_set_keymap('n', '<leader>dr', ":lua require('dap').repl.open()<CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap('n', '<leader>dr', ":lua require('dap').repl.open()<CR>", { noremap = true, silent = true })

-- So we can Use <up> <down> instead of tab cycle
vim.api.nvim_set_keymap('c', '<Up>', '<C-p>', { noremap = true })
vim.api.nvim_set_keymap('c', '<Down>', '<C-n>', { noremap = true })

-- lvim.keys.normal_mode["<leader>zl"] = ":term lf<CR>"

-- lvim.keys.normal_mode["<leader>zl"] = ":TermExec cmd='lf'<CR>"

-- lvim.keys.normal_mode["<leader>zl"] = ":lua require('lvim.core.terminal').toggle()<CR>:term lf<CR>"

-- my own which key map "z"
lvim.builtin.which_key.mappings["z"] = { name = "aharoJ" }


-------------------    LF PLUG ------------------------
vim.g.lf_map_keys = 0
-- lvim.keys.normal_mode["<leader>zl"] = ":Lf<CR>"
-- lvim.keys.normal_mode["<leader>zl"] = ":LfCurrentDirectory<CR>"
vim.api.nvim_set_keymap('n', '<leader>zl', ':Lf<CR>', { noremap = true, silent = true })
vim.g.lf_width = 80  -- This sets the width
vim.g.lf_height = 30 -- This sets the height
-- let g:lf_command_override = 'lf -command "set hidden"'
------------------------------------------------------


-- lvim.keys.normal_mode["<leader>bc"] = ":bd<CR>"


-- removes the which_key = which is the mini map thingt
lvim.builtin.which_key.mappings['c'] = {}

-- bind the command + Close Buffer
lvim.builtin.which_key.mappings["b"]["c"] = { ":bd<CR>", "Close Buffer" }

-- lua require'nvim-tree.view'.resize(40)

vim.o.scrolloff = 5   -- This sets a 5-line margin at the top and bottom.
vim.opt.cmdheight = 0 -- this is the little bar at the bottom
