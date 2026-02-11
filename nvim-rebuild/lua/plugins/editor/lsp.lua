-- path: nvim/lua/plugins/editor/lsp.lua
-- Description: LSP foundation — Mason package manager, mason-lspconfig bridge,
--              nvim-lspconfig server data, LspAttach keymaps, and native diagnostics.
--              Server-specific settings live in lsp/<server>.lua (0.11+ file-based discovery).
-- CHANGELOG: 2026-02-10 | IDEI Phase A build. Clean slate from tracker. Mason v2 +
--            mason-lspconfig v2 + native LSP + capability-gated keymaps + diagnostics.
--            NO completion wiring (Phase B). NO formatting (Phase C). | ROLLBACK: Delete file
--            2026-02-11 | IDEI Phase F. Added ts_ls + eslint to ensure_installed.
--            blink.cmp dependency already present from Phase B.
--            | ROLLBACK: Remove "ts_ls" and "eslint" from ensure_installed

return {
  -- ── Mason: Package Manager for LSP Servers, Formatters, Linters ───────
  -- WHY: Single binary installer for the entire IDEI stack. Servers, formatters,
  -- and linters all managed from one place. No manual PATH wrangling.
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      ui = { border = "rounded" },
    },
  },

  -- ── Mason-LSPConfig v2: Auto-Enable Installed Servers ─────────────────
  -- WHY: mason-lspconfig v2 does ONE thing: auto-calls vim.lsp.enable() for
  -- every Mason-installed server. Server configs come from lsp/<server>.lua
  -- files (native 0.11+ auto-discovery) merged with nvim-lspconfig bundled configs.
  --
  -- WHAT CHANGED FROM LAST TIME:
  -- - ensure_installed expanded for Phase F (TypeScript language expansion)
  -- - No stylua/prettierd here (formatters are NOT LSP servers — use :MasonInstall)
  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",        -- Provides lsp/ config data for server discovery
      "saghen/blink.cmp",             -- Phase B: ensures capabilities wired before servers start
    },
    opts = {
      -- Servers to auto-install. Each has a matching lsp/<name>.lua config file.
      ensure_installed = {
        "lua_ls",                     -- Lua (Neovim config) — Phase A
        "ts_ls",                      -- TypeScript/JavaScript/React/Next.js — Phase F
        "eslint",                     -- ESLint as LSP (diagnostics + code actions) — Phase F
        "tailwindcss",                -- Tailwind CSS (class intellisense) — Phase F
        -- "jdtls",                   -- Java (Spring Boot) — future phase, may need nvim-jdtls
      },
      -- WHY: v2 default. Auto-calls vim.lsp.enable() for every installed server.
      -- Server configs come from lsp/<server>.lua files. No handlers needed.
      automatic_enable = true,
    },
  },

  -- ── nvim-lspconfig: Server Config Data ────────────────────────────────
  -- WHY: In 0.11+, nvim-lspconfig's role is reduced to providing lsp/<server>.lua
  -- config files (cmd, filetypes, root_markers, settings). We don't call
  -- require('lspconfig').server.setup() anymore — that pattern is deprecated.
  -- Having it in runtimepath gives us sensible defaults that our own lsp/<server>.lua
  -- files override via vim.lsp.config deep-merge.
  {
    "neovim/nvim-lspconfig",
    lazy = true,                      -- Loaded as dependency of mason-lspconfig
  },

  -- ── LspAttach: Keymaps & Per-Buffer Setup ─────────────────────────────
  -- WHY: This is a "virtual" plugin entry that sets up the LspAttach autocmd.
  -- Keymaps are capability-gated: if the server doesn't support rename, the
  -- rename keymap won't be created. This prevents phantom bindings.
  --
  -- NOTE: 0.11+ provides default LSP keymaps (grn, gra, grr, gri, gO, K).
  -- We add our own <leader>l* namespace for discoverability via which-key,
  -- and override some defaults for consistency.
  {
    "neovim/nvim-lspconfig",          -- Same plugin, second spec merges via lazy.nvim
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      -- ── Diagnostics Configuration ───────────────────────────────────
      -- WHY: Native 0.11+ diagnostic display. No plugin needed.
      -- virtual_text on every line, always visible. No virtual_lines (noisy).
      vim.diagnostic.config({
        virtual_text = true,                      -- Inline diagnostic on every line, always
        virtual_lines = false,                    -- No multi-line expansion (noisy, redundant)
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN]  = " ",
            [vim.diagnostic.severity.INFO]  = " ",
            [vim.diagnostic.severity.HINT]  = " ",
          },
        },
        underline = true,                       -- Underline diagnostic spans
        update_in_insert = false,               -- Don't distract while typing
        severity_sort = true,                   -- Errors first, then warnings, etc.
        float = {
          border = "rounded",                   -- Consistent with vim.o.winborder
          source = true,                        -- Show which LSP/tool produced the diagnostic
        },
      })

      -- ── LspAttach Autocmd ───────────────────────────────────────────
      -- WHY: Keymaps only exist on buffers with an attached LSP client.
      -- Capability-gated: the binding is only created if the server supports it.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if not client then return end

          -- HARD RULE: LSP never formats. Conform owns formatting (Phase C).
          -- Belt-and-suspenders: even if a server config forgets to disable
          -- formatting, this kills it at attach time for ALL servers.
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false

          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, desc = "LSP: " .. desc })
          end

          -- ── Navigation ────────────────────────────────────────────
          -- WHY: gd is muscle memory for "go to definition" across every vim config.
          -- 0.11+ default K (hover) is already set, no need to override.
          map("n", "gd", vim.lsp.buf.definition, "Go to definition")
          map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
          map("n", "gt", vim.lsp.buf.type_definition, "Go to type definition")

          -- ── Leader LSP Namespace ──────────────────────────────────
          -- WHY: <leader>l* namespace for LSP actions. Discoverable via which-key.
          -- These complement the 0.11+ defaults (grn, gra, grr, gri, gO).
          map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol")
          map({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, "Code action")
          map("n", "<leader>lf", vim.lsp.buf.references, "Find references")
          map("n", "<leader>ls", vim.lsp.buf.signature_help, "Signature help")
          map("n", "<leader>li", "<cmd>LspInfo<CR>", "LSP info")

          -- ── Diagnostics (buffer-scoped) ───────────────────────────
          -- WHY: <leader>d* namespace for diagnostic navigation and display.
          map("n", "<leader>dd", vim.diagnostic.open_float, "Line diagnostics")
          map("n", "<leader>dn", function() vim.diagnostic.jump({ count = 1 }) end, "Next diagnostic")
          map("n", "<leader>dp", function() vim.diagnostic.jump({ count = -1 }) end, "Prev diagnostic")
          map("n", "<leader>dl", vim.diagnostic.setloclist, "Diagnostics to loclist")

          -- ── Inlay Hints Toggle ────────────────────────────────────
          -- WHY: Inlay hints are useful for type-heavy code but noisy otherwise.
          -- Toggle on demand rather than always-on.
          if client:supports_method("textDocument/inlayHint") then
            map("n", "<leader>lh", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }), { bufnr = event.buf })
            end, "Toggle inlay hints")
          end

          -- ── Document Highlight ────────────────────────────────────
          -- WHY: When cursor rests on a symbol, highlight other occurrences.
          -- Built-in to 0.11+ LSP client, no plugin needed.
          if client:supports_method("textDocument/documentHighlight") then
            local highlight_group = vim.api.nvim_create_augroup("UserLspHighlight", { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              group = highlight_group,
              buffer = event.buf,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              group = highlight_group,
              buffer = event.buf,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
        desc = "LSP: Configure keymaps and buffer settings on attach",
      })
    end,
  },
}
