-- path: nvim/lsp/lua_ls.lua
-- Description: Native 0.11+ config for lua-language-server. Auto-discovered by
--              vim.lsp.config() — no require() needed. This file lives at the nvim
--              config root (next to init.lua), NOT inside lua/.
-- CHANGELOG: 2026-02-10 | IDEI Phase A. Clean slate. Formatting disabled (conform
--            handles Lua formatting via stylua in Phase C). | ROLLBACK: Delete file
--            2026-02-11 | IDEI Phase B. Added completion.callSnippet/keywordSnippet
--            = "Disable" — server-side snippet kill switch. Prevents lua_ls from
--            generating snippet-type completion items at the source. Belt-and-suspenders
--            with transform_items filter in completion.lua.
--            | ROLLBACK: Remove the `completion` block under settings.Lua

return {
  settings = {
    Lua = {
      -- ── Runtime ─────────────────────────────────────────────────────
      runtime = {
        version = "LuaJIT",           -- Neovim uses LuaJIT, not standard Lua
      },

      -- ── Diagnostics ────────────────────────────────────────────────
      diagnostics = {
        globals = { "vim" },          -- Recognize `vim` global (Neovim API)
      },

      -- ── Workspace ──────────────────────────────────────────────────
      workspace = {
        checkThirdParty = false,      -- Don't prompt about third-party library detection
        -- Neovim runtime types for vim.* API completions.
        -- lazydev.nvim can replace this later for plugin API types too.
        library = {
          vim.env.VIMRUNTIME,
        },

      },

      -- ── Telemetry ──────────────────────────────────────────────────
      telemetry = {
        enable = false,               -- No telemetry. Ever.
      },

      -- ── Formatting ─────────────────────────────────────────────────
      -- WHY DISABLED: Formatting is stylua's job via conform.nvim (Phase C).
      -- lua_ls formatting is inferior to stylua and would create a duplicate
      -- formatting provider — exactly the anti-pattern that broke our last build.
      format = {
        enable = false,               -- CRITICAL: Prevents lua_ls from offering formatting
      },

      -- ── Completion ─────────────────────────────────────────────────
      -- WHY DISABLED: Snippets are OFF by IDEI Phase B design. These settings
      -- tell lua_ls to NOT generate snippet-type completion items at the source.
      -- Some LSPs ignore the client-side snippetSupport=false capability flag,
      -- so this is the server-side kill switch. Belt-and-suspenders with the
      -- transform_items filter in completion.lua.
      -- Reference: https://cmp.saghen.dev/configuration/snippets
      completion = {
        callSnippet = "Disable",      -- Don't expand function calls as snippets
        keywordSnippet = "Disable",   -- Don't expand keywords as snippets
      },
    },
  },
}
