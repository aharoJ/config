-- path: nvim/lua/plugins/init.lua
-- Description: Master importer. lazy.nvim loads this, which imports all subdirectories.
--              Add new categories here as they're built.
-- CHANGELOG: 2026-02-03 | Created with core and tools imports | ROLLBACK: Delete file

return {
    { import = "plugins.core" },
    { import = "plugins.core.colorscheme" },
    { import = "plugins.tools" },
    { import = "plugins.ui" },
    { import = "plugins.lang" },
    { import = "plugins.editor" },
}
