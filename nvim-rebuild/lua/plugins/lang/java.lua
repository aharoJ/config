-- path: nvim/lua/plugins/lang/java.lua
-- Description: nvim-jdtls plugin spec — extensions for eclipse.jdt.ls (Java LSP).
--              The ACTUAL jdtls configuration lives in ftplugin/java.lua (standard
--              Neovim ftplugin pattern). This spec just ensures the plugin is installed
--              and loaded when a .java file opens.
--
--              WHY nvim-jdtls over nvim-java:
--              - KISS principle: thin wrapper, full visibility into config
--              - Community standard: LazyVim, LunarVim, nvim-lspconfig all recommend it
--              - Stable: maintained by mfussenegger since 2020, minimal breaking changes
--              - Standard Mason install (no custom registry like nvim-java)
--              - Full control: cmd, workspace dirs, bundles, init_options — all explicit
--
--              WHY ftplugin pattern over vim.lsp.enable():
--              - nvim-jdtls's start_or_attach provides handlers that vim.lsp.enable doesn't
--              - jdtls is EXCLUDED from mason-lspconfig's automatic_enable to prevent
--                a duplicate basic jdtls instance from conflicting with this one
--              - ftplugin is the standard Neovim mechanism for filetype-specific setup
--
-- CHANGELOG: 2026-02-11 | IDEI Phase F2 build. Java language expansion.
--            | ROLLBACK: Delete file, delete ftplugin/java.lua, remove "jdtls"
--            from ensure_installed in lsp.lua, remove java entries from formatting.lua
return {
  "mfussenegger/nvim-jdtls",
  ft = { "java" },
  -- WHY no config function: All configuration is in ftplugin/java.lua.
  -- lazy.nvim's ft trigger ensures the plugin is loaded (making require("jdtls")
  -- available) before Neovim's ftplugin mechanism runs ftplugin/java.lua.
  -- The ftplugin file handles start_or_attach, keymaps, and settings.
  --
  -- WHY no dependencies: mason.nvim and mason-lspconfig are already loaded
  -- by plugins/editor/lsp.lua (event = BufReadPre). By the time a .java file
  -- triggers this spec, Mason infrastructure is already up.
}
