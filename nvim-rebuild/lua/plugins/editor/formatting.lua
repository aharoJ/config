-- path: nvim/lua/plugins/editor/formatting.lua
-- Description: conform.nvim — formatting engine. Manual-only via <leader>cf.
--              NO format-on-save. NO LSP formatting (killed in Phase A LspAttach).
--              Formatters: stylua for Lua, prettierd for TypeScript/JavaScript/web,
--              google-java-format for Java.
-- CHANGELOG: 2026-02-11 | Phase C build. Manual trigger only. stylua for Lua.
--            | ROLLBACK: Delete file
--            2026-02-11 | Phase F1. Added prettierd (with prettier fallback) for
--            TypeScript, JavaScript, TSX, JSX, JSON, HTML, CSS, SCSS, YAML, Markdown.
--            | ROLLBACK: Remove all non-lua entries from formatters_by_ft
--            2026-02-11 | Phase F2. Added google-java-format for Java with --aosp
--            flag (4-space indent, matches Java convention in core/autocmds.lua).
--            | ROLLBACK: Remove java entry from formatters_by_ft, remove formatters block

-- WHY a local: Used 6 times across filetypes. Avoids typos in the fallback chain.
-- prettierd is the daemon wrapper (stays warm between invocations, ~10x faster cold start).
-- prettier is the fallback if prettierd isn't installed. stop_after_first = true means
-- conform uses the FIRST available formatter, not both.
local prettier = { "prettierd", "prettier", stop_after_first = true }

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
          timeout_ms = 3000,          -- 3s timeout (prettierd is fast, but safety net)
        })
      end,
      mode = { "n", "v" },           -- Works in normal mode (whole file) and visual (range)
      desc = "Format buffer (conform)",
    },
  },
  opts = {
    -- ── Formatters by Filetype ──────────────────────────────────────────
    -- WHY: Each filetype maps to exactly ONE formatter (or fallback chain).
    -- stylua for Lua (Phase C). prettierd for everything web (Phase F1).
    -- google-java-format for Java (Phase F2). One tool per job — no LSP
    -- formatting, no overlap.
    formatters_by_ft = {
      -- Phase C (Lua)
      lua = { "stylua" },
      -- Phase F1 (TypeScript/JavaScript ecosystem)
      typescript = prettier,
      javascript = prettier,
      typescriptreact = prettier,
      javascriptreact = prettier,
      -- Phase F1 (Web formats prettier handles natively)
      json = prettier,
      jsonc = prettier,
      html = prettier,
      css = prettier,
      scss = prettier,
      yaml = prettier,
      markdown = prettier,
      graphql = prettier,
      -- Phase F2 (Java)
      java = { "google-java-format" },
      -- python = { "black" },              -- future phase
    },

    -- ── Default Format Options ──────────────────────────────────────────
    -- WHY lsp_format = "never": LSP formatting is dead. Phase A killed the
    -- capability in LspAttach, server configs have format.enable = false, and
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
