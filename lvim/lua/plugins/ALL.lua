-- Plugins
lvim.plugins = {
  -- theme --
  { "catppuccin/nvim",                            name = "catppuccin", priority = 1000 },
  { "rose-pine/neovim",                           name = "rose-pine" },
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


  { "WhoIsSethDaniel/toggle-lsp-diagnostics.nvim" },


  -- status line --
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' }
  },
  --     ...............            --
  -- {
  --   'nvim-telescope/telescope.nvim',
  --   version = '0.1.5',
  --   -- or                              , branch = '0.1.x',
  --   dependencies = { 'nvim-lua/plenary.nvim' }
  -- },




  {
    "anuvyklack/pretty-fold.nvim",
    event = "BufRead", -- Optional: this line makes the plugin load only after a buffer is read
    config = function()
      require("pretty-fold").setup {}
    end
  },




}
