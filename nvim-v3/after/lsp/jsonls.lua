-- path: ~/.config/nvim-v3/after/lsp/jsonls.lua
-- description: JSON language server with SchemaStore validation
-- patched: Phase 3 (D24, D28)
local ok, schemastore = pcall(require, "schemastore")
local schemas = ok and schemastore.json.schemas() or {}

return {
  root_markers = { "package.json", ".git" },
  init_options = {
    provideFormatter = false, -- D28: conform handles formatting
  },
  settings = {
    json = {
      schemas = schemas,
      validate = { enable = true },
      format = { enable = false }, -- D28: belt-and-suspenders
    },
  },
}
