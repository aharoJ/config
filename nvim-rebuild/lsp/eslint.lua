-- path: nvim/lsp/eslint.lua
-- Description: Native 0.11+ config for eslint-lsp (vscode-eslint-language-server).
--              Auto-discovered by vim.lsp.config() — no require() needed.
--              Runs as LSP server for clean diagnostic merge into vim.diagnostic
--              and access to code actions (disable rule, fix all, show docs).
--              Formatting DISABLED (conform.nvim + prettierd owns formatting).
-- WHY eslint as LSP (not nvim-lint): nvim-lint uses a SEPARATE diagnostic namespace
--   from LSP (confirmed: mfussenegger/nvim-lint#826). Diagnostics don't merge on
--   the same line — creates visual clutter. eslint-lsp merges cleanly into
--   vim.diagnostic AND provides code actions nvim-lint can't (EslintFixAll,
--   disable-rule comments). nvim-lint stays reserved for tools without LSP option.
-- CHANGELOG: 2026-02-11 | IDEI Phase F build. ESLint as LSP for TypeScript.
--            Best-of merge: Claude A (root_markers, workingDirectories, codeActionOnSave),
--            Claude B (codeAction settings, on_attach structure).
--            | ROLLBACK: Delete file, remove "eslint" from ensure_installed in lsp.lua

return {
  -- ── Root Detection ────────────────────────────────────────────────────
  -- WHY explicit root_markers: eslint needs to find the project's eslint config.
  -- Flat config (eslint.config.*) listed first — it's the modern standard (ESLint 9+).
  -- Legacy configs (.eslintrc.*) still supported for existing projects.
  root_markers = {
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    "eslint.config.ts",
    "eslint.config.mts",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.json",
    ".eslintrc.yml",
    ".eslintrc.yaml",
    ".eslintrc",
    "package.json",
  },

  -- ── Formatting Kill (on_attach) ───────────────────────────────────────
  -- WHY: eslint-lsp CAN format (EslintFixAll is formatting-adjacent). We kill
  -- the formatting capability so conform is the ONLY formatting path.
  -- EslintFixAll still works as a code action — it doesn't need the
  -- documentFormattingProvider capability to function.
  -- Belt-and-suspenders with the global LspAttach kill in Phase A.
  on_attach = function(client, _bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,

  settings = {
    -- ── Validation ────────────────────────────────────────────────────
    validate = "on",

    -- ── Working Directories ──────────────────────────────────────────
    -- WHY mode = "auto": eslint-lsp auto-detects the working directory from
    -- the eslint config location. Handles monorepos correctly without manual
    -- workingDirectories config. Avoids the 4.8.0→4.10.0 workingDirectories
    -- bug that caused silent failures in some project structures.
    workingDirectories = {
      mode = "auto",
    },

    -- ── Code Action on Save ──────────────────────────────────────────
    -- WHY disabled: We don't want eslint auto-fixing on save. Manual control
    -- only. Use code actions (gra) to apply individual fixes, or run
    -- :EslintFixAll explicitly when you want bulk fixes.
    codeActionOnSave = {
      enable = false,
    },

    -- ── Code Actions ────────────────────────────────────────────────
    -- WHY: eslint's code actions (auto-fix, disable-rule, EslintFixAll) are
    -- the main reason to run eslint as LSP instead of through nvim-lint.
    codeAction = {
      disableRuleComment = {
        enable = true,                -- Allow "Disable eslint rule" code action
        location = "separateLine",    -- eslint-disable on its own line, not inline
      },
      showDocumentation = {
        enable = true,                -- Allow "Show documentation for rule" code action
      },
    },
  },
}
