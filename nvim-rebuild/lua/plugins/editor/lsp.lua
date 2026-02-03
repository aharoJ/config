-- path: nvim/lua/plugins/editor/lsp.lua
-- Description: LSP infrastructure — Mason for server installation, mason-lspconfig v2 for
--              auto-enabling, LspAttach for keymaps, and native vim.diagnostic configuration.
--              Server-specific settings live in lsp/<server>.lua (0.11+ file-based discovery).
-- CHANGELOG: 2026-02-03 | Initial Phase 2 build. Mason v2 + mason-lspconfig v2 + native LSP
--            pattern. Diagnostics config folded in here (no plugin needed). | ROLLBACK: Delete file

return {
  -- ── Mason: Package Manager for LSP Servers, Formatters, Linters ───────
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },

  -- ── Mason-LSPConfig v2: Auto-Enable Installed Servers ─────────────────
  -- WHY: mason-lspconfig v2 dropped handlers/setup_handlers(). It now does ONE thing:
  -- auto-calls vim.lsp.enable() for installed servers. Server configs come from
  -- lsp/<server>.lua files (native 0.11+) or nvim-lspconfig's bundled configs.
  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",        -- Provides lsp/ config files for server discovery
      "saghen/blink.cmp",             -- Capabilities must be available before servers start
    },
    config = function()
      -- Wire blink.cmp completion capabilities to ALL LSP servers.
      -- WHY: blink.cmp advertises extra capabilities (snippets, completionItem/resolve, etc.)
      -- that the default Neovim client doesn't. Without this, some completion features are
      -- silently unavailable. vim.lsp.config('*') applies to every server universally.
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      require("mason-lspconfig").setup({
        -- Servers to auto-install if not present. Add more as needed for your stack.
        -- Your stack: Spring Boot (Java), React/Next.js (TS), PostgreSQL, Lua
        ensure_installed = {
          "lua_ls",                   -- Lua (Neovim config)
          "ts_ls",                    -- TypeScript/JavaScript
          -- "jdtls",                 -- Java (Spring Boot) — complex, may need nvim-jdtls plugin
          -- "html",                  -- HTML
          -- "cssls",                 -- CSS
          -- "jsonls",                -- JSON
          -- "tailwindcss",           -- Tailwind CSS
          -- "eslint",                -- ESLint as LSP
        },
        -- WHY: v2 default. Mason-lspconfig calls vim.lsp.enable() for every installed server
        -- automatically. Server configs come from lsp/<server>.lua files. No handlers needed.
        automatic_enable = true,
      })
    end,
  },

  -- ── nvim-lspconfig: Server Config Data ────────────────────────────────
  -- WHY: In 0.11+, nvim-lspconfig's role is reduced to providing lsp/<server>.lua config
  -- files (cmd, filetypes, root_markers, settings). We don't call require('lspconfig').setup()
  -- anymore — that pattern is deprecated. Mason-lspconfig handles vim.lsp.enable().
  {
    "neovim/nvim-lspconfig",
    lazy = true,                      -- Loaded as dependency of mason-lspconfig
  },

  -- ── LspAttach Autocmd: Keymaps + Per-Buffer Setup ─────────────────────
  -- WHY: LSP keymaps belong here, not in core/keymaps.lua (which is plugin-free).
  -- This fires once per buffer when an LSP client attaches.
  {
    "neovim/nvim-lspconfig",          -- Spec merges with the one above in lazy.nvim
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      -- ── Diagnostic Configuration (native, zero plugins) ──────────────
      -- WHY virtual_lines current_line: Shows full multi-line diagnostic ONLY under cursor.
      -- Clean lines everywhere else. Inspired by lsp_lines.nvim, now built into 0.11+.
      vim.diagnostic.config({
        virtual_text = true,          -- Short inline message at end of line (always visible)
        virtual_lines = {
          current_line = true,        -- Full diagnostic detail below cursor line only
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN]  = " ",
            [vim.diagnostic.severity.INFO]  = " ",
            [vim.diagnostic.severity.HINT]  = "󰌵 ",
          },
        },
        underline = true,             -- Underline the problematic code
        update_in_insert = false,     -- Don't update diagnostics while typing (too noisy)
        severity_sort = true,         -- Errors first in sign column and lists
        float = {
          border = "rounded",         -- Consistent with vim.o.winborder
          source = true,              -- Show which LSP/linter produced the diagnostic
        },
      })

      -- ── LspAttach Keymaps ────────────────────────────────────────────
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
        desc = "LSP keymaps and per-buffer setup on attach",
        callback = function(event)
          local buf = event.buf
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = "LSP: " .. desc })
          end

          -- ── Navigation (Tier 1: leader + single key or g-prefix) ─────
          map("n", "gd", vim.lsp.buf.definition, "Go to definition")
          map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          map("n", "gt", vim.lsp.buf.type_definition, "Go to type definition")

          -- ── 0.11+ Built-in Defaults (documented here for reference) ──
          -- grn → vim.lsp.buf.rename()           (built-in 0.11+)
          -- gra → vim.lsp.buf.code_action()      (built-in 0.11+)
          -- grr → vim.lsp.buf.references()       (built-in 0.11+)
          -- gri → vim.lsp.buf.implementation()   (built-in 0.11+)
          -- gO  → vim.lsp.buf.document_symbol()  (built-in 0.11+)
          -- K   → vim.lsp.buf.hover()            (built-in 0.11+)
          -- <C-S> → vim.lsp.buf.signature_help() (built-in 0.11+, insert mode)

          -- ── Diagnostics (Tier 1: leader + d namespace) ───────────────
          map("n", "<leader>dd", vim.diagnostic.open_float, "Show diagnostic float")
          map("n", "<leader>dl", vim.diagnostic.setloclist, "Diagnostics → location list")
          map("n", "<leader>dq", vim.diagnostic.setqflist, "Diagnostics → quickfix list")
          map("n", "[d", function()
            vim.diagnostic.jump({ count = -1 })
          end, "Previous diagnostic")
          map("n", "]d", function()
            vim.diagnostic.jump({ count = 1 })
          end, "Next diagnostic")

          -- ── Toggle Diagnostics (Tier 2: leader + dt) ─────────────────
          -- WHY: Sometimes you need clean lines during focused editing. Toggle back when done.
          map("n", "<leader>dt", function()
            vim.diagnostic.enable(not vim.diagnostic.is_enabled())
          end, "Toggle diagnostics")

          -- ── Workspace ────────────────────────────────────────────────
          map("n", "<leader>la", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
          map("n", "<leader>lr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
          map("n", "<leader>ll", function()
            vim.notify(vim.inspect(vim.lsp.buf.list_workspace_folders()), vim.log.levels.INFO)
          end, "List workspace folders")

          -- ── Inlay Hints (0.11+, if server supports them) ─────────────
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method("textDocument/inlayHint") then
            map("n", "<leader>lh", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }))
            end, "Toggle inlay hints")
          end
        end,
      })
    end,
  },
}
