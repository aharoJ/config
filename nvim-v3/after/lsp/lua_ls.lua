-- path: ~/.config/nvim-v3/after/lsp/lua_ls.lua
-- description: Lua language server — Neovim config development
-- patched: Phase 3 (D24, D28)
return {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = {
        checkThirdParty = false,
        library = { vim.env.VIMRUNTIME },
      },
      format = { enable = false }, -- D28: belt-and-suspenders, conform handles formatting
      telemetry = { enable = false },
      completion = {
        callSnippet = "Disable", -- Phase 4: change to "Replace" when snippets enabled
        keywordSnippet = "Disable",
      },
    },
  },
}
