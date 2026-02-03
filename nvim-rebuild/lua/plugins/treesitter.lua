-- plugins/treesitter.lua
-- Syntax highlighting, indentation, incremental selection.
--
-- nvim-treesitter `main` branch (2025) is a complete rewrite:
--   - `nvim-treesitter.configs` module no longer exists
--   - `highlight = { enable = true }` is gone
--   - Parser install is now explicit: require('nvim-treesitter').install({...})
--   - Highlighting/indent/folding use Neovim's built-in APIs

return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  lazy = false, -- load at startup so parsers are available immediately
  config = function()
    local ts = require("nvim-treesitter")

    -- Minimal setup (only install_dir is accepted)
    ts.setup({})

    -- Install parsers (async, non-blocking)
    ts.install({
      "lua",
      "java",
      "typescript",
      "tsx",
      "javascript",
      "python",
      "rust",
      "go",
      "sql",
      "html",
      "css",
      "json",
      "yaml",
      "toml",
      "bash",
      "fish",
      "markdown",
      "markdown_inline",
      "vim",
      "vimdoc",
      "query",
      "regex",
    })

    -- Enable treesitter highlighting + indentation for all filetypes
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true }),
      callback = function(args)
        -- Try to start highlighting; silently fails if no parser exists
        pcall(vim.treesitter.start, args.buf)
        -- Enable treesitter-based indentation
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
