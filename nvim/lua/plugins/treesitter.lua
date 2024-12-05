return {
  "nvim-treesitter/nvim-treesitter",
  dependencies = { "HiPhish/nvim-ts-rainbow2" },
  run = ":TSUpdate",

  config = function()
    local config = require("nvim-treesitter.configs")
    -- require("plugins.autopair")
    config.setup({
      sync_install = false,
      auto_install = true,
      ensure_installed = { "lua", "python", "json", "http", "typescript", "xml"},
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
      -- -------------------    RAINBOW Custom   ------------------------
      vim.cmd("highlight CustomRainbowPurple guifg=#4a3b4d"),
      vim.cmd([[
      " hi 1 guifg=#E06C75 " red
      hi 1 guifg=#C986A8 " pink
      hi 2 guifg=#86A8C9 " baby blue
      hi 3 guifg=#C98686 " baby redish
      hi 4 guifg=#9086C9 " baby purple
      hi 5 guifg=#C9C786 " baby yellow
      hi 6 guifg=#86C99D " baby green
      hi 7 guifg=#C99886 " baby orange
      ]]),
      rainbow = {
        enable = false,
        disable = { "jsx", "cpp" },
        query = "rainbow-parens",
        strategy = require("ts-rainbow").strategy.global,
        hlgroups = {
          "6",
          "TSRainbowBlue",
          "2",
          "1",
          "7",
          "4",
          "3",
          "5",
          -- "TSRainbowBlue",
          -- "TSRainbowViolet", -- a nice purple-redish color
          -- "TSRainbowCyan", -- nice brown-goldish color
          -- "TSRainbowGreen",
          -- "TSRainbowRed",
          -- "TSRainbowYellow",
          -- "TSRainbowOrange",
          -- ----------------                       ------------------------
        },
      },
    })
  end,
}
