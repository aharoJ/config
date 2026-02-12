-- path: nvim/lua/plugins/lang/json.lua
-- Description: SchemaStore.nvim — provides ~500 JSON/YAML schemas from
--              schemastore.org for jsonls and yamlls. Pure data library, no UI.
--              Loaded on-demand when lsp/jsonls.lua calls require("schemastore").
--
-- WHY plugins/editor/ (not plugins/lang/json.lua):
--   SchemaStore.nvim serves BOTH jsonls (now) AND yamlls (future Phase F8).
--   It's a cross-language editor data library, not a JSON-specific plugin.
--   plugins/editor/ parallels other shared editor infrastructure
--   (lsp.lua, formatting.lua, lint.lua).
--
-- CHANGELOG: 2026-02-12 | IDEI Phase F12. JSON language expansion.
--            Required by jsonls (now) and yamlls (future phase).
--            | ROLLBACK: Delete file, remove schemas line from lsp/jsonls.lua

return {
  -- ── SchemaStore.nvim: JSON Schema Catalog ─────────────────────────────
  -- WHY: Provides the full schemastore.org catalog (~500 schemas) as a
  -- Lua table. jsonls uses these to provide schema-driven completion,
  -- validation, and hover documentation for common JSON files.
  --
  -- ARCHITECTURE: This is a pure DATA plugin — no setup(), no config(),
  -- no side effects. It's loaded lazily when lsp/jsonls.lua calls
  -- require("schemastore").json.schemas(). The catalog is a static table
  -- that maps file patterns to schema URLs.
  --
  -- FEATURES NOT USED (but available for future customization):
  --   select = { "package.json", "tsconfig.json" }  -- subset only
  --   ignore = { ".eslintrc" }                       -- exclude specific
  --   replace = { ["package.json"] = "custom_url" }  -- override schema URL
  --   extra = { { name = "...", ... } }              -- add custom schemas
  -- We use the full catalog — no reason to restrict on M4 Max.
  "b0o/SchemaStore.nvim",
  lazy = true,           -- Only loaded when require("schemastore") is called
  -- WHY version = false: The last tagged release is ancient (v0.2.0, May 2023).
  -- The catalog is auto-generated from schemastore.org on every commit to main.
  -- Pinning to a release would give you years-old schemas. Always use HEAD.
  version = false,
}
