-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny
vim.opt.shell = "/bin/sh"


-- Plugins 
lvim.plugins = {
  -- ... other plugin entries will be here
    {"catppuccin/nvim", name = "catppuccin", priority = 1000},
    {"ThePrimeagen/vim-be-good"},             -- vim-be-good plugin
    { "rose-pine/neovim", name = "rose-pine"},
    {"mfussenegger/nvim-jdtls"},


    {"ldelossa/nvim-dap-projects"},
    {"mfussenegger/nvim-dap"},
    {"rcarriga/nvim-dap-ui"},
    {"theHamsta/nvim-dap-virtual-text"},
  

  {
      "folke/todo-comments.nvim",
      event = "BufRead",
      config = function ()
      require ("todo-comments").setup ()
      end
    },
}

-- Key mappings
lvim.keys.normal_mode = {
  ["<C-d>"] = "<C-d>zz",  -- Scroll down half a page and center the line
  ["<C-u>"] = "<C-u>zz",  -- Scroll up half a page and center the line
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



vim.opt.wrap = true -- wrap lines
vim.opt.relativenumber = true -- relative line numbers
--vim.opt.cmdheight = 2 -- more space in the neovim command line for displaying messages
vim.opt.guifont = "monospace:h17" -- the font used in graphical neovim applications
vim.opt.tabstop = 2 -- insert 4 spaces for a tab
vim.opt.shiftwidth = 2 -- the number of spaces inserted for each indentation


lvim.builtin.lualine.style = "default" -- or "none"

vim.opt.hlsearch= false
vim.opt.incsearch= true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
--vim.opt.isfname: append ("@-@")
--vim.opt.updatetime = 50


local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  {
    command = "clang-format",
    filetypes = { "java" },
  }
}








local dap = require('dap')

dap.adapters.java = function(callback, config)
  -- This should point to the `java-debug-adapter` executable or script
  local executable = '/path/to/java-debug-adapter'
  callback({ type = 'executable', command = executable })
end

dap.configurations.java = {
  {
    -- The name of the configuration, shown in the UI
    name = 'Launch Java',
    type = 'java',
    request = 'launch',
    -- Path to the compiled .class or .jar file you want to debug
    program = '${workspaceFolder}/path/to/java/Main.class',
    -- Specify classpaths if necessary
    classPaths = {'${workspaceFolder}'},
    -- This should point to the project's root directory
    cwd = '${workspaceFolder}',
    -- Any other launch options
    stopOnEntry = true,
    args = {},
  },
}

vim.api.nvim_set_keymap('n', '<leader>r', ':w!<CR>:!javac % && java %<CR>', { noremap = true, silent = true })










