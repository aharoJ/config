-- path: nvim/lsp/jsonls.lua
-- Description: Native 0.11+ config for vscode-json-language-server (jsonls).
--              Auto-discovered by vim.lsp.config() — no require() needed.
--              Schema validation powered by SchemaStore.nvim (~500 schemas:
--              package.json, tsconfig.json, .eslintrc, docker-compose, etc.).
--
-- WHAT THIS DOES:
--   Diagnostics:  jsonls syntax parsing + schema validation (SchemaStore.nvim)
--   Completion:   blink.cmp ← jsonls (schema-driven property/value suggestions)
--   Formatting:   KILLED (four layers) — conform.nvim owns formatting (prettierd, Phase F1)
--   Hover:        jsonls (schema-driven property descriptions)
--   Doc Symbols:  jsonls (navigate JSON structure with gO)
--   Goto Def:     jsonls ($ref resolution in JSON schemas)
--
-- CRITICAL GOTCHAS (from research):
--
--   1. Settings MUST nest under settings.json, NOT settings directly.
--      Wrong: settings = { schemas = ... }
--      Right: settings = { json = { schemas = ... } }
--      (blink.cmp#2096, SchemaStore.nvim#8 — silent failure if wrong)
--
--   2. validate.enable = true MUST be set explicitly.
--      Upstream bug: when ANY settings.json config is provided, jsonls
--      treats unspecified options as false (not their actual defaults).
--      Without this, diagnostics silently stop working. No error, no
--      warning — just no schema validation.
--      (SchemaStore.nvim#8, confirmed by maintainer, vscode source L230-239)
--
--   3. jsonls requires snippetSupport capability for completions.
--      blink.cmp advertises this by default via capability merging (Phase B).
--      Our transform_items snippet filter is safe: jsonls sends property
--      completions as kind=Property (with snippet insertTextFormat for
--      tab stops like "key": $1), NOT kind=Snippet. They pass through.
--
-- ANTI-PATTERN #19: DO NOT add jsonlint or similar to nvim-lint.
--   jsonls schema validation IS the linting. Duplicate diagnostics guaranteed.
--
-- FORMATTING KILL (four layers — belt, suspenders, backup suspenders):
--   Layer 1: init_options.provideFormatter = false (server startup, earliest)
--   Layer 2: settings.json.format.enable = false (server config)
--   Layer 3: on_attach capability kill (client-side, after handshake)
--   Layer 4: Global LspAttach safety net in plugins/editor/lsp.lua (Phase A)
--
-- CHANGELOG: 2026-02-12 | IDEI Phase F12 build. JSON language expansion.
--            jsonls + SchemaStore.nvim for schema intelligence, prettierd via
--            conform (Phase F1, already configured). Four-layer formatting kill.
--            | ROLLBACK: Delete file, remove "jsonls" from ensure_installed in lsp.lua,
--            delete plugins/editor/schemastore.lua

return {
  -- ── Root Detection ────────────────────────────────────────────────────
  -- WHY: package.json signals a Node project (where most JSON editing
  -- happens in the React/Next.js/Spring Boot stack). .git is the fallback
  -- for standalone JSON files. single_file_support (nvim-lspconfig default)
  -- handles files opened outside any project.
  root_markers = {
    "package.json",
    ".git",
  },

  -- ── Init Options (Layer 1 — earliest formatting kill) ─────────────────
  -- WHY: provideFormatter = false tells jsonls at server startup "don't
  -- register ANY formatting capability." This fires BEFORE the server
  -- advertises capabilities to the client. The nvim-lspconfig bundled
  -- default is provideFormatter = true — we override it.
  -- jsonls only supports range formatting (not full-document), which is
  -- inferior to prettierd anyway. Kill it at the source.
  init_options = {
    provideFormatter = false,
  },

  -- ── Server Settings ─────────────────────────────────────────────────────
  settings = {
    -- ── CRITICAL: Must nest under "json", NOT directly under "settings" ──
    -- jsonls reads settings.json.schemas, settings.json.validate, etc.
    -- Putting schemas/validate at settings root = silently ignored.
    json = {
      -- ── Schemas (SchemaStore.nvim) ──────────────────────────────────
      -- WHY: ~500 schemas from schemastore.org. Covers package.json,
      -- tsconfig.json, .eslintrc, .prettierrc, docker-compose, GitHub
      -- Actions workflows, lazy-lock.json, and hundreds more.
      -- Without schemas, jsonls only validates JSON syntax (brackets, commas).
      -- WITH schemas, it validates structure, types, required fields, enums,
      -- and provides intelligent completion/hover for every known file format.
      --
      -- require("schemastore") is safe here — lsp/ files are evaluated lazily
      -- when jsonls first starts. SchemaStore.nvim is a pure data library
      -- (no setup()), so the require() just returns the catalog table.
      schemas = require("schemastore").json.schemas(),

      -- ── Validation (Layer 0 — schema validation itself) ────────────
      -- WHY enable = true EXPLICITLY: Upstream bug in vscode-json-language-server.
      -- When you provide ANY settings.json config (like schemas above), jsonls
      -- treats unspecified options as false instead of using defaults. Without
      -- this line, validation silently stops. Diagnostics disappear. No errors.
      -- You just don't get red squiggles on invalid JSON anymore.
      -- Reference: SchemaStore.nvim#8, vscode source code line 230-239.
      validate = {
        enable = true,
      },

      -- ── Formatting Kill (Layer 2 — server config) ──────────────────
      -- WHY: Tells jsonls internally "don't prepare formatting responses."
      -- Belt-and-suspenders with init_options (Layer 1) and on_attach (Layer 3).
      -- prettierd via conform is the sole JSON formatter.
      format = {
        enable = false,
      },
    },
  },

  -- ── Formatting Kill (Layer 3 — on_attach capability) ──────────────────
  -- WHY: Even after init_options and settings kills, we strip capabilities
  -- as defense-in-depth. This matches the pattern used by every other
  -- IDEI language config (lua_ls, ts_ls, bashls, taplo, fish_lsp).
  -- Layer 4 (global LspAttach safety net) lives in plugins/editor/lsp.lua.
  on_attach = function(client, _bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
