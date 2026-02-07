
# 🧠 Neovim 2025 — Full Java + LSP + Formatting + Linting Setup
*A complete reference for my modern Neovim environment — JDTLS, LSP, Conform formatting, and nvim-lint all working together.*

---

## 📦 Plugin Overview

| Area          | Plugin(s)                               | Notes |
|--------------|---------------------------------------|------|
| **LSP Core** | `neovim/nvim-lspconfig`, `mason.nvim`, `mason-lspconfig.nvim` | Installs + configures language servers for most languages. |
| **Java**     | `mfussenegger/nvim-jdtls`              | Special setup for Java (JDTLS not managed by mason-lspconfig). |
| **Debugging**| `mfussenegger/nvim-dap`, `rcarriga/nvim-dap-ui`, `nvim-neotest/nvim-nio` | Used for hot code replace, main-class debug discovery. |
| **Completion**| `hrsh7th/nvim-cmp` + friends          | LSP-aware autocompletion with snippets. |
| **Formatting**| `stevearc/conform.nvim`               | Handles formatting (including fallback to LSP). |
| **Linting**  | `mfussenegger/nvim-lint`               | Async linting for non-LSP tools (ruff, eslint, shellcheck, etc). |

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

      -- Example servers (NEVER include jdtls here)
      lspconfig.lua_ls.setup({ capabilities = caps })
      lspconfig.pyright.setup({ capabilities = caps })
      lspconfig.clangd.setup({ capabilities = caps })
      -- ... add more as needed
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

---

## ☕ Java JDTLS Setup (Standalone)

**File:** `lua/core/jdtls.lua`

Key points:

* **Manual start** via autocmd — avoids duplicate LSP client issues.
* **Workspace per project root** stored under `stdpath("data")/jdtls/workspace`.
* **DAP wiring** auto-discovers main classes for F5 debugging.
* **Lombok + runtime autodetect** (via `$LOMBOK_JAR` and `$JAVA_21_HOME`).

```lua
function M.start_or_attach()
  local root = project_root()
  if not root or root == "" then
    vim.notify("[jdtls] no project root found", vim.log.levels.WARN)
    return
  end

  local jdtls_home = jdtls_base_dir()
  local ws = fn.stdpath("data") .. "/jdtls/workspace/" .. project_name(root)
  fn.mkdir(ws, "p")

  local jdtls = require("jdtls")
  local config = {
    cmd = build_cmd(jdtls_home, ws),
    root_dir = root,
    settings = settings_java(),
    init_options = {
      bundles = bundles_all(),
      extendedClientCapabilities = extended_capabilities(),
    },
    capabilities = lsp_capabilities(),
    on_attach = on_attach,
    flags = { allow_incremental_sync = true },
  }

  jdtls.start_or_attach(config)
end
```

**File:** `lua/plugins/lsp/java.lua`

```lua
return {
  {
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp",
      { "mfussenegger/nvim-dap", lazy = true },
      { "rcarriga/nvim-dap-ui", lazy = true, dependencies = { "nvim-neotest/nvim-nio" }, config = true },
      { "theHamsta/nvim-dap-virtual-text", lazy = true, config = true },
    },
    config = function()
      require("core.jdtls").setup_autocmd()
    end,
  },
}
```

---

## 🎨 Formatting — Conform.nvim

**File:** `lua/plugins/formatting/conform.lua`

* Runs **stylua**, **isort+black**, **prettierd**, etc.
* Falls back to LSP formatting if no formatter found.
* Java uses JDTLS built-in formatter.

```lua
opts = {
  formatters_by_ft = {
    lua = { "stylua" },
    python = function(bufnr)
      local conform = require("conform")
      if conform.get_formatter_info("ruff_format", bufnr).available then
        return { "ruff_format" }
      else
        return { "isort", "black" }
      end
    end,
    c = { "clang_format" },
    cpp = { "clang_format" },
    java = { lsp_format = "prefer" }, -- let JDTLS format
    javascript = { "prettierd", "prettier", stop_after_first = true },
    typescript = { "prettierd", "prettier", stop_after_first = true },
    markdown = { "prettierd", "prettier", "injected" },
    ["_"] = { "trim_whitespace" },
  },
  default_format_opts = { lsp_format = "fallback", timeout_ms = 1000 },
  format_on_save = function(bufnr)
    if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
    return { lsp_format = "fallback", timeout_ms = 500 }
  end,
}
```

> 💡 Tip: Toggle autoformatting easily:
>
> ```vim
> :FormatDisable   " disables globally
> :FormatDisable!  " disables buffer-local
> :FormatEnable    " re-enables
> ```

---

## 🧹 Linting — nvim-lint

**File:** `lua/plugins/linting/nvim-lint.lua`

* Runs Ruff for Python (but ignores F-series errors to avoid duplicating Pyright).
* Runs eslint\_d, shellcheck, rubocop, phpcs, sqlfluff, etc.
* Debounced linting on `BufWritePost`, `BufEnter`, `InsertLeave`.

```lua
lint.linters_by_ft = {
  lua   = { "luacheck" },
  sh    = { "shellcheck" },
  bash  = { "shellcheck" },
  fish  = { "fish" },
  python = { "ruff" }, -- style only; LSP covers type errors
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
```

---

## 🧩 Diagnostic Deduplication

To avoid duplicate diagnostics:

* Pyright handles undefined variables + type checking.
* Ruff restricted to style rules (E, W, etc).
* Configured eslint\_d to run only if `.eslintrc` or `eslint.config.js` exists.

```lua
-- Example: Ruff args (disable F errors)
local ruff = lint.linters.ruff
if ruff then
  ruff.args = { "check", "--quiet", "--select=E,W,I,N,UP,B,C4,SIM,PIE,ISC,RUF", "--stdin-filename", function() return vim.api.nvim_buf_get_name(0) end, "-" }
  ruff.stdin = true
end
```

---

## 🔑 Keymaps (Muscle Memory)

| Key          | Action                              |
| ------------ | ----------------------------------- |
| `<leader>f`  | Format buffer (or visual selection) |
| `:Format`    | Force format current buffer         |
| `:Lint`      | Run linters manually                |
| `<leader>jo` | Organize imports (Java)             |
| `<leader>jv` | Extract variable (Java)             |
| `<leader>jm` | Extract method (Java)               |

---

## 🧪 Debugging Checklist

* Run `:ConformInfo` to verify available formatters.
* Run `:lua =require('lint').linters_by_ft` to check active linters.
* `:LspInfo` shows attached servers & root markers.
* Check `:messages` or `~/.local/state/nvim/lsp.log` for errors.

---

## 📌 Summary

✅ **LSP** — Handles semantic diagnostics & completions
✅ **JDTLS** — Separate, project-root-aware Java experience
✅ **Conform** — Smart formatting with LSP fallback
✅ **nvim-lint** — Asynchronous linters (only where they add value)
✅ **No duplicate diagnostics** — Pyright handles types, Ruff handles style

---

> 💾 Save this note in Obsidian under `Neovim/2025-Setup.md`.
> Next time you upgrade plugins, revisit this guide to verify nothing breaks (especially JDTLS and Conform API changes).

```

