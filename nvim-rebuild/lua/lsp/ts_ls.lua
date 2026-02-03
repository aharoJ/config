-- path: nvim/lsp/ts_ls.lua
-- Description: Native 0.11+ config for ts_ls (TypeScript Language Server).
--              Auto-discovered by vim.lsp.config() — no require needed.
-- CHANGELOG: 2026-02-03 | Initial Phase 2 build | ROLLBACK: Delete file

return {
  on_attach = function(client, bufnr)
    -- WHY: Disable ts_ls formatting — we use prettierd/prettier via conform.nvim instead.
    -- ts_ls formatting is inconsistent with Prettier's output, and Prettier is the standard
    -- for React/Next.js projects.
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
  settings = {
    typescript = {
      inlayHints = {
        -- WHY: Inlay hints are available but off by default. Toggle with <leader>lh (LspAttach).
        -- These show parameter names, return types, etc. inline.
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
    javascript = {
      inlayHints = {
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
  },
}
