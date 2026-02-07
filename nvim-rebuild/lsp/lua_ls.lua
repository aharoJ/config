-- path: nvim/lsp/lua_ls.lua
-- Description: Native 0.11+ config for lua_ls (Lua Language Server).
--              Auto-discovered by vim.lsp.config() — no require needed.
--              Mason installs the binary; this file configures its behavior.
-- CHANGELOG: 2026-02-03 | Initial Phase 2 build | ROLLBACK: Delete file

return {
  settings = {
    Lua = {
      -- WHY: Neovim uses LuaJIT runtime, not standard Lua 5.1
      runtime = { version = "LuaJIT" },
      -- WHY: Recognize vim as a global without diagnostic warnings
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        -- WHY: Prevents the "Do you want to configure workspace?" popup
        checkThirdParty = false,
      },
      telemetry = {
        -- WHY: No data sent to third parties
        enable = false,
      },
    },
  },
}
