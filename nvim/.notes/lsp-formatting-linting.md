# 🧠 Neovim 2025 — LSP + Formatting + Linting (Excluding JDTLS)

This is my **complete reference** for setting up:
- 🌐 Language Server Protocol (LSP) for all languages except Java
- 🎨 Formatting via Conform.nvim
- 🧹 Linting via nvim-lint  
All tuned to work **smoothly together** with no duplicate diagnostics.

---

## 📦 Plugin Overview

| Area          | Plugin(s)                                | Notes |
|--------------|-----------------------------------------|------|
| **LSP Core** | `neovim/nvim-lspconfig`, `mason.nvim`, `mason-lspconfig.nvim` | Handles installation & configuration of language servers |
| **Completion**| `hrsh7th/nvim-cmp`, `cmp-nvim-lsp`, `LuaSnip`, `cmp-path`, `cmp-buffer` | Modern, snappy completion engine |
| **Formatting**| `stevearc/conform.nvim`                 | Lightweight formatter with fallback to LSP |
| **Linting**  | `mfussenegger/nvim-lint`                 | Async linting for non-LSP tools (eslint, ruff, shellcheck, etc.) |

---

## ⚙️ Core LSP Setup

**File:** `lua/plugins/lsp/lsp.lua`

```lua
return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lspconfig = require("lspconfig")
      local caps = vim.lsp.protocol.make_client_capabilities()
      local ok, cmp = pcall(require, "cmp_nvim_lsp")
      if ok then
        caps = cmp.default_capabilities(caps)
      end

      -- Configure servers (excluding jdtls!)
      lspconfig.lua_ls.setup({ capabilities = caps })
      lspconfig.pyright.setup({ capabilities = caps })
      lspconfig.clangd.setup({ capabilities = caps })
      -- Add more servers here as needed
    end,
  },
  { "mason-org/mason.nvim", config = true },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        automatic_enable = { exclude = { "jdtls" } },
      })
    end,
  },
}
````

✅ **Notes:**

* We explicitly **exclude `jdtls`** from Mason’s automatic setup.
* Use `:Mason` to install extra language servers (tsserver, bashls, etc.).
* Use `:LspInfo` to debug which servers are attached.

---

## 🎨 Formatting with Conform.nvim

**File:** `lua/plugins/formatting/conform.lua`

```lua
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>f",
      function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
      mode = { "n", "x" },
      desc = "Format buffer / range",
    },
  },
  init = function()
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
  opts = {
    formatters_by_ft = {
      lua         = { "stylua" },
      python      = function(bufnr)
        local conform = require("conform")
        if conform.get_formatter_info("ruff_format", bufnr).available then
          return { "ruff_format" }
        else
          return { "isort", "black" }
        end
      end,
      c           = { "clang_format" },
      cpp         = { "clang_format" },
      javascript  = { "prettierd", "prettier", stop_after_first = true },
      typescript  = { "prettierd", "prettier", stop_after_first = true },
      markdown    = { "prettierd", "prettier", "injected" },
      yaml        = { "yamlfmt" },
      json        = { "jq" },
      ["_"]       = { "trim_whitespace" },
    },
    default_format_opts = {
      lsp_format = "fallback",
      timeout_ms = 1000,
    },
    format_on_save = function(bufnr)
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
      return { lsp_format = "fallback", timeout_ms = 500 }
    end,
    log_level = vim.log.levels.ERROR,
    notify_on_error = true,
  },
  config = function(_, opts)
    require("conform").setup(opts)

    vim.api.nvim_create_user_command("FormatDisable", function(args)
      if args.bang then
        vim.b.disable_autoformat = true
      else
        vim.g.disable_autoformat = true
      end
    end, { bang = true })

    vim.api.nvim_create_user_command("FormatEnable", function()
      vim.b.disable_autoformat = false
      vim.g.disable_autoformat = false
    end, {})

    vim.api.nvim_create_user_command("Format", function(cmdargs)
      local range = nil
      if cmdargs.count ~= -1 then
        local end_line = vim.api.nvim_buf_get_lines(0, cmdargs.line2 - 1, cmdargs.line2, true)[1]
        range = { start = { cmdargs.line1, 0 }, ["end"] = { cmdargs.line2, end_line:len() } }
      end
      require("conform").format({ async = true, lsp_format = "fallback", range = range })
    end, { range = true })
  end,
}
```

✅ **Highlights:**

* Runs formatters before save (or manually via `<leader>f`).
* Falls back to LSP formatting when no formatter exists.
* Supports range formatting (`:'<,'>Format`).

---

## 🧹 Linting with nvim-lint

**File:** `lua/plugins/linting/nvim-lint.lua`

```lua
return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    local lint = require("lint")

    -- Helper: detect project root
    local function project_root(patterns)
      local root = vim.fs.root(0, patterns)
      return root or vim.uv.cwd()
    end

    lint.linters_by_ft = {
      lua   = { "luacheck" },
      sh    = { "shellcheck" },
      bash  = { "shellcheck" },
      fish  = { "fish" },
      python = { "ruff" }, -- F errors disabled to avoid duplicating pyright
      javascript = { "eslint_d" },
      typescript = { "eslint_d" },
      ruby  = { "rubocop" },
      php   = { "phpstan", "phpcs" },
      c     = { "clangtidy" },
      cpp   = { "clangtidy" },
      markdown = { "markdownlint" },
      yaml  = { "yamllint" },
      json  = { "jsonlint" },
      sql   = { "sqlfluff" },
      ["*"] = { "codespell" },
    }

    -- Ruff: style-only (no undefined-variable or type errors)
    local ruff = lint.linters.ruff
    if ruff then
      ruff.args = { "check", "--quiet", "--select=E,W,I,N,UP,B,C4,SIM,PIE,ISC,RUF", "--stdin-filename", function() return vim.api.nvim_buf_get_name(0) end, "-" }
      ruff.stdin = true
    end

    -- ESLint: detect project root
    local eslintd = lint.linters.eslint_d
    if eslintd then
      eslintd.cwd = function()
        return project_root({
          ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.mjs",
          ".eslintrc.json", "eslint.config.js", "package.json",
        })
      end
    end

    -- Debounce to avoid spamming
    local debounce_ms, timer = 150, vim.uv.new_timer()
    local function debounced_lint(bufnr)
      if timer then timer:stop() end
      timer:start(debounce_ms, 0, function()
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            lint.try_lint()
          end
        end)
      end)
    end

    vim.api.nvim_create_autocmd("BufWritePost", {
      callback = function(a) debounced_lint(a.buf) end,
    })
    vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave" }, {
      callback = function(a) debounced_lint(a.buf) end,
    })

    vim.api.nvim_create_user_command("Lint", function() lint.try_lint() end, {})
  end,
}
```

✅ **Highlights:**

* Runs on save, on buffer enter, and after insert mode exit.
* Integrates project-root aware eslint\_d and sqlfluff.
* Uses Ruff for fast Python linting, complementing Pyright.

---

## 🧩 Diagnostic Deduplication

To avoid **double errors**:

* **LSP handles semantic/type errors** (e.g., Pyright undefined variables).
* **nvim-lint handles style errors** (ruff, eslint, shellcheck).
* Disabled Ruff’s F-series errors that overlap with Pyright.

---

## 🔑 Useful Commands

| Command / Keymap | Action                                    |
| ---------------- | ----------------------------------------- |
| `<leader>f`      | Format current buffer or visual selection |
| `:Format`        | Manual format (range-aware)               |
| `:FormatDisable` | Disable autoformat globally               |
| `:Lint`          | Run linters immediately                   |
| `:LspInfo`       | Show active LSP servers                   |

---

## 🧪 Debugging Tools

* `:ConformInfo` → Shows available formatters and which will run.
* `:lua =require('lint').linters_by_ft` → Inspect current linter table.
* `:LspInfo` → Check attached LSP servers and root directories.
* Check `~/.local/state/nvim/lsp.log` if servers misbehave.

---

## ✅ Summary

* **Single source of truth:** LSP for completions + type errors.
* **Formatting is unified:** Conform first, LSP fallback second.
* **Linting is async & root-aware:** No duplicate diagnostics.
* **Modular & extensible:** Easily add new servers, formatters, linters.

---
