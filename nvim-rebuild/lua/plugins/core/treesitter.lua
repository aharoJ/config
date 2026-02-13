-- path: nvim/lua/plugins/core/treesitter.lua
-- Description: Syntax highlighting, indentation, and parser management.
--              Uses nvim-treesitter MAIN branch (2025 incompatible rewrite):
--                - The old require('nvim-treesitter.configs').setup({}) API is GONE
--                - setup() is minimal (only install_dir)
--                - Parser install is explicit via require('nvim-treesitter').install({...})
--                - Highlighting/indentation/folding are NOT auto-enabled by the plugin
--                - YOU enable features via Neovim's native APIs (vim.treesitter.start, etc.)
--              Folding is already configured globally in core/options.lua (foldmethod/foldexpr).
-- CHANGELOG: 2026-02-04 | Full rewrite for nvim-treesitter main branch | ROLLBACK: Delete file

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",                    -- Explicit: main is the 2025 rewrite, master is frozen
  lazy = false,                       -- Plugin does NOT support lazy-loading (per upstream README)
  build = ":TSUpdate",                -- Keep parsers pinned to compatible versions on plugin update

  config = function()
    local ts = require("nvim-treesitter")

    -- ── Minimal Setup ───────────────────────────────────────────
    -- WHY: The only config the main branch accepts is install_dir.
    -- Default (stdpath("data") .. "/site") is correct — no override needed.
    ts.setup({})

    -- ── Parser Installation ─────────────────────────────────────
    -- WHY: ensure_installed is gone in the rewrite. Explicit install is the new way.
    -- install() is async and non-blocking — M4 Max makes this near-instant.
    -- Parsers match the stack: Spring Boot (Java), React/Next.js (TS/TSX/JS),
    -- MariaDB (SQL), plus config/infra languages used daily.
    ts.install({
      -- Primary stack
      "java",
      "typescript",
      "tsx",
      "javascript",
      "sql",
      "lua",

      -- Web
      "html",
      "css",
      "json",
      "jsonc",

      -- Config & infrastructure
      "yaml",
      "toml",
      "bash",
      "fish",

      -- Documentation & prose
      "markdown",
      "markdown_inline",

      -- Neovim internals (required for :checkhealth, help files, query debugging)
      "vim",
      "vimdoc",
      "query",
      "luadoc",
      "regex",
      "diff",

      -- Future-proofing (languages you touch occasionally)
      "python",
      "rust",
      "go",
      "c",
      "xml",
      "graphql",
      "dockerfile",
      "gitcommit",
      "gitignore",
      "git_config",
    })

    -- ── Enable Highlighting & Indentation Per Buffer ────────────
    -- WHY: The main branch no longer auto-enables anything.
    -- vim.treesitter.start() enables highlighting using Neovim's built-in engine.
    -- indentexpr enables treesitter-based indentation (experimental, but works well
    -- for the languages in this stack — especially Lua, TS, Java).
    -- pcall guards against filetypes that don't have a parser installed.
    -- pattern = "*" means any filetype — parsers without a match silently no-op.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("UserTreesitterStart", { clear = true }),
      callback = function(args)
        -- Skip special buffer types (quickfix, help already has its own highlighting, etc.)
        local buf = args.buf
        if vim.bo[buf].buftype ~= "" then
          return
        end

        -- Enable treesitter highlighting for this buffer
        -- pcall: silently skips filetypes without an installed parser
        local ok = pcall(vim.treesitter.start, buf)
        if not ok then
          return
        end

        -- Enable treesitter-based indentation (experimental but solid for our stack)
        -- WHY Lua excluded: treesitter Lua indent queries return 0 in empty regions
        -- between code blocks (no enclosing scope detected). smartindent handles
        -- Lua correctly — it uses the previous line's indent level.
        if vim.bo[buf].filetype ~= "lua" then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
      desc = "Start treesitter highlighting and indentation per buffer",
    })

    -- NOTE: Folding is already configured globally in core/options.lua:
    --   vim.opt.foldmethod = "expr"
    --   vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    -- No need to set it here — it works automatically when a parser is available.
  end,
}
