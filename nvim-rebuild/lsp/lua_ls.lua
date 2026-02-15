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
--            2026-02-13 | SNIPPETS ENABLED. Changed callSnippet/keywordSnippet from
--            "Disable" to "Replace". lua_ls now generates snippet completions for
--            function calls (with parameter placeholders) and keywords (with body
--            templates). Works with blink.cmp's snippets source + friendly-snippets.
--            | ROLLBACK: Set callSnippet/keywordSnippet back to "Disable"

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
      -- WHY "Replace": Function calls expand with parameter placeholders
      -- (e.g., accepting `vim.keymap.set` inserts `vim.keymap.set(mode, lhs, rhs)`
      -- with tabstops). Keywords expand with body templates (e.g., `for` expands
      -- to a full for-loop skeleton). Navigate placeholders with <C-l>/<C-k>.
      -- Previously "Disable" during Phase B (snippet isolation). Now enabled
      -- alongside friendly-snippets and blink.cmp's snippets source.
      completion = {
        callSnippet = "Replace",      -- Function calls include parameter placeholders
        keywordSnippet = "Replace",   -- Keywords expand to full body templates
      },
    },
  },
}
