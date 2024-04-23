-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny
vim.opt.shell = "/bin/sh"
vim.g.mapleader = " "
lvim.lsp.automatic_servers_installation = false


-- Plugins
lvim.plugins = {
  -- ... other plugin entries will be here
  { "catppuccin/nvim",                name = "catppuccin", priority = 1000 },
  { "ThePrimeagen/vim-be-good" }, -- vim-be-good plugin
  { "rose-pine/neovim",               name = "rose-pine" },
  { "mfussenegger/nvim-jdtls" },
  { "williamboman/mason.nvim" },


  { "ldelossa/nvim-dap-projects" },
  { "mfussenegger/nvim-dap" },
  { "rcarriga/nvim-dap-ui" },
  { "theHamsta/nvim-dap-virtual-text" },
  { "neovim/nvim-lspconfig" },
  { "rcarriga/cmp-dap" },
  { "ptzz/lf.vim" },
  { "voldikss/vim-floaterm" },



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
vim.opt.tabstop = 2    -- insert 4 spaces for a tab
vim.opt.shiftwidth = 2 -- the number of spaces inserted for each indentation


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


-------------------    LF PLUG ------------------------
-- lvim.keys.normal_mode["<leader>zl"] = ":Lf<CR>"
lvim.keys.normal_mode["<leader>zl"] = ":LfCurrentDirectory<CR>"
------------------------------------------------------






-- lvim.keys.normal_mode["<leader>bc"] = ":bd<CR>"


-- removes the which_key = which is the mini map thingt
lvim.builtin.which_key.mappings['c'] = {}

-- my own which key map "z"
lvim.builtin.which_key.mappings["z"] = { name = "aharoJ" }



-- bind the command + Close Buffer
lvim.builtin.which_key.mappings["b"]["c"] = { ":bd<CR>", "Close Buffer" }

-- lua require'nvim-tree.view'.resize(40)



-- config = function()
--   require("neo-tree").setup({
--     close_if_last_window = true,
--     window = {
--       width = 30,
--     },
--     buffers = {
--       follow_current_file = true,
--     },
--     filesystem = {
--       follow_current_file = true,
--       filtered_items = {
--         hide_dotfiles = false,
--         hide_gitignored = false,
--         hide_by_name = {
--           "node_modules"
--         },
--         never_show = {
--           ".DS_Store",
--           "thumbs.db"
--         },
--       },
--     },
--   })
-- end



vim.o.scrolloff = 5 -- This sets a 5-line margin at the top and bottom.
vim.opt.cmdheight = 0



-- -- This is a basic setup. Check the plugin's documentation for more options.
-- lvim.builtin.nvimtree = {
--   active = true,
--   on_config_done = nil,
--   setup = {
--     disable_netrw = true,
--     hijack_netrw = true,
--     open_on_setup = false,
--     ignore_ft_on_setup = {},
--     open_on_tab = false,
--     update_cwd = true,
--     renderer = {
--       add_trailing = false,
--       group_empty = false,
--       highlight_git = false,
--       highlight_opened_files = "none",
--       root_folder_modifier = ":~",
--       indent_markers = {
--         enable = false,
--       },
--       icons = {
--         glyphs = {
--           default = "",
--           symlink = "",
--           git = {
--             unstaged = "✗",
--             staged = "✓",
--             unmerged = "",
--             renamed = "➜",
--             untracked = "★",
--             deleted = "",
--             ignored = "◌",
--           },
--           folder = {
--             default = "",
--             open = "",
--             empty = "",
--             empty_open = "",
--             symlink = "",
--           },
--         },
--       },
--     },
--     diagnostics = {
--       enable = false,
--       icons = {
--         hint = "",
--         info = "",
--         warning = "",
--         error = "",
--       },
--     },
--     update_focused_file = {
--       enable = false,
--       update_cwd = false,
--       ignore_list = {},
--     },
--     system_open = {
--       cmd = nil,
--       args = {},
--     },
--     filters = {
--       dotfiles = false,
--       custom = {},
--       exclude = {},
--     },
--     git = {
--       enable = true,
--       ignore = true,
--       timeout = 500,
--     },
--     view = {
--       width = 30,
--       hide_root_folder = false,
--       side = "left",
--       mappings = {
--         custom_only = false,
--         list = {},
--       },
--       number = false,
--       relativenumber = false,
--       signcolumn = "yes",
--     },
--     actions = {
--       open_file = {
--         resize_window = true,
--         window_picker = {
--           enable = true,
--         },
--       },
--     },
--   },
-- }





-- This is a basic setup. Check the plugin's documentation for more options.
lvim.builtin.nvimtree = {
  active = true,
  on_config_done = nil,
  setup = {
    disable_netrw = true,
    hijack_netrw = true,
    open_on_setup = false,
    ignore_ft_on_setup = {},
    open_on_tab = false,
    update_cwd = true,
    renderer = {
      add_trailing = false,
      group_empty = false,
      highlight_git = false,
      highlight_opened_files = "none",
      root_folder_modifier = ":~",
      indent_markers = {
        enable = false,
      },
      icons = {
        glyphs = {
          default = "",
          symlink = "",
          git = {
            unstaged = "✗",
            staged = "✓",
            unmerged = "",
            renamed = "➜",
            untracked = "★",
            deleted = "",
            ignored = "◌",
          },
          folder = {
            default = "",
            open = "",
            empty = "",
            empty_open = "",
            symlink = "",
          },
        },
      },
    },
    diagnostics = {
      enable = false,
      icons = {
        hint = "",
        info = "",
        warning = "",
        error = "",
      },
    },
    update_focused_file = {
      enable = false,
      update_cwd = false,
      ignore_list = {},
    },
    system_open = {
      cmd = nil,
      args = {},
    },
    filters = {
      dotfiles = false,
      custom = {},
      exclude = {},
    },
    git = {
      enable = true,
      ignore = true,
      timeout = 500,
    },
    view = {
      width = 50,
      hide_root_folder = false,
      side = "left",
      mappings = {
        custom_only = false,
        list = {
          { key = "l", action = "edit" },
        },
      },
      number = true,
      relativenumber = true,
      signcolumn = "yes",
    },
    actions = {
      open_file = {
        resize_window = true,
        window_picker = {
          enable = true,
        },
      },
    },
  },
}
