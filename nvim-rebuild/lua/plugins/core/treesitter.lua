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
-- CHANGELOG: 2026-02-13 | Lua exclusion from treesitter indent (empty-region bug) | ROLLBACK: Remove Lua filetype guard
-- CHANGELOG: 2026-02-13 | Switch indent from blocklist to allowlist | ROLLBACK: Revert to previous blocklist pattern

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

        -- ── Pre-flight Check ────────────────────────────────────────
    -- WHY: The main branch requires tree-sitter-cli (>=0.25.0) to compile
    -- parsers. Without it, install() hangs indefinitely with NO error
    -- (known bug: nvim-treesitter#7873, #8010, #8426). Fail loud instead.
    if vim.fn.executable("tree-sitter") ~= 1 then
      vim.notify(
        "tree-sitter-cli not found! Parsers cannot be compiled.\n"
          .. "Install via: brew install tree-sitter",
        vim.log.levels.ERROR
      )
      return
    end

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

    -- ── Treesitter Indent Allowlist ─────────────────────────────
    -- WHY: Treesitter indentation is EXPERIMENTAL (upstream says so explicitly).
    -- Not all parsers ship indent queries (indents.scm). For those that don't,
    -- setting indentexpr overrides Vim's built-in indent plugins with effectively
    -- autoindent — a downgrade. Even among languages WITH indent queries, some
    -- have known bugs (Lua: empty-region returns 0, Python: docstrings/multiline).
    --
    -- Strategy: ALLOWLIST languages where treesitter indent is known-good.
    -- Everything else keeps Vim's built-in indent or smartindent from options.lua.
    --
    -- To add a language: verify it has an I (indent) column in :checkhealth,
    -- test o/O/== in representative files, then add to this set.
    local ts_indent_langs = {
      -- C-family: well-tested, brace-delimited scopes work reliably
      java = true,
      javascript = true,
      typescript = true,
      tsx = true,
      c = true,
      rust = true,
      go = true,

      -- Data/markup: simple structure, indent queries are straightforward
      json = true,
      jsonc = true,
      html = true,
      css = true,
      yaml = true,
      toml = true,
      xml = true,
      query = true,          -- Treesitter query files themselves

      -- sql: has indent queries, simple enough to work
      sql = true,
    }
    -- EXCLUDED (with reasons):
    -- lua:             Empty regions between code blocks return indent 0 (column 1).
    --                  smartindent handles Lua correctly via previous-line heuristic.
    -- python:          Most-reported indent language in nvim-treesitter. Issues with
    --                  docstrings, multiline expressions, end-of-scope detection.
    --                  Vim's built-in python indent ($VIMRUNTIME/indent/python.vim) is mature.
    -- markdown:        Breaks breakindent settings, list indent interaction issues.
    --                  Vim's built-in markdown indent handles this better.
    -- bash:            NO indent queries (indents.scm missing). Setting indentexpr
    --                  overrides Vim's excellent built-in sh.vim indent which knows
    --                  if/fi, case/esac, do/done, function bodies.
    -- fish:            NO indent queries. Let smartindent handle it.
    -- vim/vimdoc:      NO indent queries. Vim's built-in indent handles vimscript.
    -- diff/regex/luadoc/dockerfile/gitcommit/gitignore/git_config/graphql:
    --                  NO indent queries. These are mostly non-editable or trivial.
    -- markdown_inline: Injected language, indent handled by markdown parent parser.

    -- ── Enable Highlighting & Indentation Per Buffer ────────────
    -- WHY: The main branch no longer auto-enables anything.
    -- vim.treesitter.start() enables highlighting using Neovim's built-in engine.
    -- indentexpr enables treesitter-based indentation for allowlisted languages only.
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

        -- Enable treesitter-based indentation ONLY for allowlisted languages
        -- All others keep Vim's built-in indent plugins or smartindent
        local ft = vim.bo[buf].filetype
        if ts_indent_langs[ft] then
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
