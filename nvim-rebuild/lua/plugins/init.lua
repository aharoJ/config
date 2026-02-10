-- path: nvim/lua/plugins/init.lua
-- Description: Master importer. lazy.nvim loads this, which imports all subdirectories.
--              Add new categories here as they're built.
-- CHANGELOG: 2026-02-03 | Created with core and tools imports | ROLLBACK: Delete file

return {
  { import = "plugins.core" },
  { import = "plugins.core.colorscheme" },
  { import = "plugins.tools" },
   { import = "plugins.ui" },        -- Phase 2: statusline, bufferline, explorer
  -- { import = "plugins.lang" },      -- Phase 3: language-specific configs
  { import = "plugins.editor" },    -- Phase 5: LSP, completion, diagnostics, formatting
}
