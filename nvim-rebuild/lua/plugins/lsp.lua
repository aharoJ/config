-- plugins/lsp.lua
-- Language Server Protocol. Neovim 0.11 + mason-lspconfig v2.
--
-- What changed (mason-lspconfig v2):
--   - setup_handlers() is REMOVED
--   - automatic_enable = true (default) auto-calls vim.lsp.enable() for installed servers
--   - Server config via vim.lsp.config() (Neovim 0.11 native API)
--
-- What changed (Neovim 0.11 default keymaps):
--   - K, grr, gri, gra, grn, grt, gO, Ctrl-S are all built-in now
--   - [d, ]d, [D, ]D, <C-w>d are built-in since 0.10
--   - We only map keys that are NOT defaults

return {
  -- Mason: LSP server installer
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    opts = {},
  },

  -- lspconfig: provides default LSP server configurations
  { "neovim/nvim-lspconfig", lazy = true },

  -- Mason-lspconfig: bridge between mason and lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      -- ── Capabilities (extended by nvim-cmp if available) ──
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if ok then
        capabilities = cmp_lsp.default_capabilities(capabilities)
      end

      -- ── Global config: applies to ALL servers ──
      vim.lsp.config("*", {
        capabilities = capabilities,
      })

      -- ── Per-server config ──
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })

      -- ── Mason + mason-lspconfig ──
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "ts_ls",
          "jdtls",
          "pyright",
          "rust_analyzer",
          "tailwindcss",
          "html",
          "cssls",
          "jsonls",
          "yamlls",
          "bashls",
        },
        -- automatic_enable = true is the default
        -- Automatically calls vim.lsp.enable() for every installed server
      })

      -- ── Keymaps on LspAttach ──
      -- Only map what Neovim 0.11 does NOT provide by default.
      -- Built-in defaults (do NOT remap): K, grr, gri, gra, grn, grt, gO,
      --   Ctrl-S, [d, ]d, [D, ]D, <C-w>d
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
        callback = function(args)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = args.buf, desc = "LSP: " .. desc })
          end

          -- Navigation (not built-in defaults)
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")

          -- Leader-based shortcuts (ergonomic alternatives to gr* defaults)
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ds", vim.lsp.buf.document_symbol, "Document symbols")
          map("<leader>ws", vim.lsp.buf.workspace_symbol, "Workspace symbols")
          map("<leader>e", vim.diagnostic.open_float, "Show diagnostic")
        end,
      })

      -- ── Diagnostic display ──
      vim.diagnostic.config({
        virtual_text = { spacing = 4, prefix = "●" },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = "rounded",
          source = true,
        },
      })
    end,
  },
}
