-- path: nvim/lua/plugins/editor/formatting.lua
-- Description: conform.nvim — external formatter runner with LSP fallback.
--              Handles format-on-save, per-filetype formatter config, and the <leader>cf keymap.
--              WHY not native vim.lsp.buf.format(): Many LSPs replace the entire buffer (clobbers
--              extmarks, folds, cursor). conform calculates minimal diffs and preserves state.
--              It also enables formatter chaining and range formatting for all formatters.
-- CHANGELOG: 2026-02-03 | Initial Phase 2 build. Formatters for Lua, TS/JS, Java, HTML/CSS/JSON.
--            | ROLLBACK: Delete file

return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },          -- Load before save (for format-on-save)
  cmd = { "ConformInfo" },            -- Also load on :ConformInfo command
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Format buffer (or selection)",
    },
    {
      "<leader>ct",
      function()
        -- WHY: Toggle for when format-on-save is unwanted (e.g., editing third-party code,
        -- debugging a formatter issue, or working in a repo without formatter config).
        vim.g.disable_autoformat = not vim.g.disable_autoformat
        local state = vim.g.disable_autoformat and "disabled" or "enabled"
        vim.notify("Format-on-save " .. state, vim.log.levels.INFO)
      end,
      desc = "Toggle format-on-save",
    },
  },

  opts = {
    -- ── Format on Save ──────────────────────────────────────────────────
    -- WHY function: Allows conditional skipping via the toggle keymap above.
    -- 500ms timeout prevents hanging on slow formatters during save.
    format_on_save = function(bufnr)
      if vim.g.disable_autoformat then
        return
      end
      return {
        timeout_ms = 500,
        lsp_format = "fallback",      -- Try conform formatters first, LSP if none configured
      }
    end,

    -- ── Default Options ─────────────────────────────────────────────────
    default_format_opts = {
      lsp_format = "fallback",        -- Consistent: always prefer external, fall back to LSP
    },

    -- ── Formatters by Filetype ──────────────────────────────────────────
    -- WHY explicit per-filetype: No magic. You know exactly which formatter runs on which file.
    -- Install formatters via Mason (:MasonInstall stylua prettierd google-java-format) or
    -- your system package manager.
    --
    -- NOTE: prettierd is preferred over prettier for speed (daemon mode). Falls back to
    -- prettier if prettierd is not available.
    formatters_by_ft = {
      -- Lua
      lua = { "stylua" },

      -- JavaScript / TypeScript ecosystem
      javascript = { "prettierd", "prettier", stop_after_first = true },
      javascriptreact = { "prettierd", "prettier", stop_after_first = true },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      typescriptreact = { "prettierd", "prettier", stop_after_first = true },

      -- Web
      html = { "prettierd", "prettier", stop_after_first = true },
      css = { "prettierd", "prettier", stop_after_first = true },
      scss = { "prettierd", "prettier", stop_after_first = true },

      -- Data formats
      json = { "prettierd", "prettier", stop_after_first = true },
      jsonc = { "prettierd", "prettier", stop_after_first = true },
      yaml = { "prettierd", "prettier", stop_after_first = true },
      markdown = { "prettierd", "prettier", stop_after_first = true },

      -- Java (Spring Boot)
      -- WHY google-java-format: Standard in the Java ecosystem. Opinionated but consistent.
      -- Install: :MasonInstall google-java-format
      java = { "google-java-format" },

      -- SQL
      -- WHY: sql-formatter handles PostgreSQL dialect well.
      -- Install: npm install -g sql-formatter (or :MasonInstall sql-formatter)
      -- sql = { "sql_formatter" },

      -- Shell (when Fish/Bash scripts need formatting)
      -- sh = { "shfmt" },
    },

    -- ── Formatter Overrides ─────────────────────────────────────────────
    -- WHY: Customize individual formatter behavior when defaults aren't enough.
    formatters = {
      stylua = {
        -- WHY: Respect project-level .stylua.toml if present, otherwise use sensible defaults.
        -- stylua auto-discovers config files, so no extra args needed here.
        prepend_args = {},
      },
      -- google-java-format defaults are fine (Google style, 100-char line width).
      -- Override here if you use a different Java style:
      -- ["google-java-format"] = {
      --   prepend_args = { "--aosp" },  -- Android style (4-space indent)
      -- },
    },
  },
}
