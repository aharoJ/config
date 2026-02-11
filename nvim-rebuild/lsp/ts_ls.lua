-- path: nvim/lsp/ts_ls.lua
-- Description: Native 0.11+ config for typescript-language-server (ts_ls).
--              Auto-discovered by vim.lsp.config() — no require() needed.
--              Covers TypeScript, JavaScript, TSX, JSX, and React/Next.js projects.
--              Formatting DISABLED (conform.nvim + prettierd owns formatting).
--              Unused variable diagnostics (6133, 6196) SUPPRESSED — eslint handles
--              these via @typescript-eslint/no-unused-vars with more configurability.
-- CHANGELOG: 2026-02-11 | IDEI Phase F build. TypeScript language expansion.
--            Best-of merge: Claude A (ignoredCodes, root_markers, preferTypeOnlyAutoImports),
--            Claude B (format.enable belt-and-suspenders, inlay hints structure).
--            | ROLLBACK: Delete file, remove "ts_ls" from ensure_installed in lsp.lua

return {
  -- ── Root Detection ────────────────────────────────────────────────────
  -- WHY explicit root_markers: Ensures ts_ls attaches at the correct project
  -- root. Without this, 0.11+ may use cwd or fail to find the root in
  -- monorepo setups. Order matters — tsconfig.json first for TS projects.
  root_markers = {
    "tsconfig.json",
    "jsconfig.json",
    "package.json",
    ".git",
  },

  -- ── Formatting Kill (on_attach) ───────────────────────────────────────
  -- WHY: Belt-and-suspenders with format.enable = false in settings AND
  -- the global formatting kill in LspAttach (Phase A). Three layers.
  on_attach = function(client, _bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,

  settings = {
    -- ── Diagnostics Filter ────────────────────────────────────────────
    -- WHY code 6133: TypeScript's "declared but never read" diagnostic.
    -- eslint's @typescript-eslint/no-unused-vars handles the same check with
    -- more configurability (underscore prefix patterns, args: "after-used", etc.).
    -- Suppressing here prevents duplicate "unused variable" diagnostics.
    -- Code 6196: "declared but never used" (type-only variant, same overlap).
    diagnostics = {
      ignoredCodes = { 6133, 6196 },
    },

    typescript = {
      -- ── Formatting Kill (settings) ──────────────────────────────────
      -- WHY DISABLED: Formatting is prettierd's job via conform.nvim (Phase F).
      -- ts_ls formatting is inconsistent with Prettier for JSX/TSX. This is
      -- belt-and-suspenders with the on_attach capability kill above AND the
      -- global LspAttach kill in Phase A. Three-layer kill, same as lua_ls.
      format = {
        enable = false,
      },

      -- ── Inlay Hints ────────────────────────────────────────────────
      -- WHY configured but OFF by default: Inlay hints are toggled via
      -- <leader>lh (Phase A LspAttach). These settings define WHAT shows
      -- when hints are enabled — parameter names, return types, etc.
      inlayHints = {
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },

      -- ── Import Preferences ─────────────────────────────────────────
      -- WHY preferTypeOnlyAutoImports: Cleaner tree-shaking, explicit about
      -- what's a type vs value import. Standard for modern React/Next.js.
      -- NOTE: importModuleSpecifierPreference intentionally omitted — the
      -- default ("shortest") respects tsconfig paths aliases (@/components).
      -- Setting "relative" would fight Next.js path aliases.
      preferences = {
        preferTypeOnlyAutoImports = true,
      },
    },

    javascript = {
      format = {
        enable = false,
      },
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
