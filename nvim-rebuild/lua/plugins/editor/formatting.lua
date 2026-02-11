-- path: nvim/lua/plugins/editor/formatting.lua
-- Description: conform.nvim — formatting engine. Manual-only via <leader>cf.
--              NO format-on-save. NO LSP formatting (killed in Phase A LspAttach).
--              Formatters: stylua for Lua. Expand in Phase F for other languages.
-- CHANGELOG: 2026-02-11 | Phase C build. Manual trigger only. stylua for Lua.
--            | ROLLBACK: Delete file

return {
  "stevearc/conform.nvim",

  -- WHY these load triggers: cmd for :ConformInfo diagnostics.
  -- keys for lazy-loading only when you actually format.
  -- No event trigger — conform doesn't need to load until you press the keymap.
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({
          bufnr = 0,
          lsp_format = "never",       -- NEVER use LSP formatting (conform owns this)
          async = false,              -- Synchronous: see the result immediately
          timeout_ms = 3000,          -- 3s timeout (stylua is fast, but safety net)
        })
      end,
      mode = { "n", "v" },           -- Works in normal mode (whole file) and visual (range)
      desc = "Format buffer (conform)",
    },
  },

  opts = {
    -- ── Formatters by Filetype ──────────────────────────────────────────
    -- WHY Lua-only: Phase C validates formatting in isolation with one language.
    -- Other languages added in Phase F after Lua toolchain sign-off.
    formatters_by_ft = {
      lua = { "stylua" },
      -- typescript = { "prettier" },    -- Phase F
      -- javascript = { "prettier" },    -- Phase F
      -- java = { "google-java-format" }, -- Phase F
      -- python = { "black" },           -- Phase F
    },

    -- ── Default Format Options ──────────────────────────────────────────
    -- WHY lsp_format = "never": LSP formatting is dead. Phase A killed the
    -- capability in LspAttach, lua_ls has format.enable = false, and now
    -- conform also refuses to delegate to LSP. Triple kill. One tool per job.
    default_format_opts = {
      lsp_format = "never",
    },

    -- ── NO format_on_save ───────────────────────────────────────────────
    -- WHY ABSENT (not even set to false): The IDEI principle is manual-only
    -- formatting. Omitting the key entirely means conform never hooks into
    -- BufWritePre. No auto-formatting. Ever. You format when YOU decide.
    -- format_on_save = DO NOT ADD THIS KEY

    -- ── Notifications ───────────────────────────────────────────────────
    notify_on_error = true,           -- Know when formatting fails
    notify_no_formatters = true,      -- Know when no formatter is configured for a filetype
  },
}
