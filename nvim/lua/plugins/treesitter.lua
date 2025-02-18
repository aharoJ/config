return {
  "nvim-treesitter/nvim-treesitter",
  run = ":TSUpdate",

  config = function()
    local configs = require("nvim-treesitter.configs")
    configs.setup({
      sync_install = false,
      auto_install = true,
      ensure_installed = { "lua", "python", "json", "http", "typescript", "xml" },
      -- ignore_install = { "javascript" },

      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "gnn", -- set to `false` to disable one of the mappings
          node_incremental = "grn",
          scope_incremental = "grc",
          node_decremental = "grm",
        },
      },

      autotag = {
        enable = true,
      },

      indent = {
        enable = true,
      },

      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },

      -- Treesitter Inspect
      -- vim.keymap.set("n", "<Leader>mm", "<cmd>Inspect<CR>", {
      --   desc = "Treesitter Inspect Node",
      --   noremap = true,
      --   silent = true,
      -- }),
    })
  end,
}
