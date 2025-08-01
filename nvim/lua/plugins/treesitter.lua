-- path: nvim/lua/plugins/treesitter.lua

-- path: nvim/lua/plugins/treesitter.lua
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
    "nvim-treesitter/nvim-treesitter-context",
    "windwp/nvim-ts-autotag",
  },

  config = function()
    ---------------------------------------------------------------------------
    -- Treesitter core ---------------------------------------------------------
    ---------------------------------------------------------------------------
    local configs = require("nvim-treesitter.configs")

    configs.setup({
      sync_install = false,
      auto_install = true,
      ensure_installed = {
        "lua",
        "python",
        "json",
        "http",
        "typescript",
        "javascript",
        "tsx",
        "html",
        "css",
        "xml",
        "vim",
        "vimdoc",
        "markdown_inline",
        "query",
        "java",
      },

      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "gnn",
          node_incremental = "grn",
          scope_incremental = "grc",
          node_decremental = "grm",
        },
      },

      indent = { enable = true },
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
        disable = function(_, buf)
          local max = 100 * 1024 -- 100 KB
          local ok, stat = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          return ok and stat and stat.size > max
        end,
      },
    })

    -- Handy inspection key
    vim.keymap.set("n", "<Leader>gx", "<cmd>Inspect<CR>", {
      desc = "Treesitter Inspect Node",
      noremap = true,
      silent = true,
    })

    require("nvim-ts-autotag").setup({
      -- global options go under `opts`
      opts = {
        enable_close = true,      -- <div → <div></div>
        enable_rename = true,     -- rename both tags
        enable_close_on_slash = true, -- </ auto‑closes
      },
    })
  end,
}
