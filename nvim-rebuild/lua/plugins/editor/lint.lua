-- path: nvim/lua/plugins/editor/lint.lua
-- Description: nvim-lint — async linting engine. Auto-triggers on save and file open.
--              Linters run ALONGSIDE LSP diagnostics, not instead of them. For Lua,
--              lua_ls covers all diagnostics — no external linter needed. This file
--              is infrastructure for Phase F when eslint, ruff, markdownlint arrive.
-- CHANGELOG: 2026-02-11 | IDEI Phase D build. Empty linters_by_ft for Lua-only phase.
--            Auto-trigger on BufWritePost + BufReadPost (matches LSP diagnostic model).
--            | ROLLBACK: Delete file

return {
  "mfussenegger/nvim-lint",

  -- WHY BufReadPost + BufWritePost: Linting is passive like LSP diagnostics — you
  -- don't manually trigger lua_ls, so you shouldn't manually trigger eslint either.
  -- BufReadPost = lint when opening a file. BufWritePost = lint after saving.
  -- No BufReadPre — we lint AFTER the buffer is loaded, not during.
  event = { "BufReadPost", "BufWritePost" },

  opts = {
    -- ── Linters by Filetype ───────────────────────────────────────────────
    -- WHY EMPTY: Lua diagnostics come from lua_ls exclusively. No external
    -- linter needed. Phase F populates this for other languages:
    --   typescript/javascript → eslint      (catches what ts_ls misses)
    --   python                → ruff        (fast, replaces flake8+isort)
    --   markdown              → markdownlint
    -- Each entry = exactly ONE linter per filetype. One tool per job.
    linters_by_ft = {
      -- typescript = { "eslint" },       -- Phase F
      -- javascript = { "eslint" },       -- Phase F
      -- typescriptreact = { "eslint" },  -- Phase F
      -- javascriptreact = { "eslint" },  -- Phase F
      -- python = { "ruff" },             -- Phase F
      -- markdown = { "markdownlint" },   -- Phase F
    },
  },

  config = function(_, opts)
    local lint = require("lint")

    -- Apply linters_by_ft
    lint.linters_by_ft = opts.linters_by_ft

    -- ── Auto-trigger Autocmd ────────────────────────────────────────────
    -- WHY: Matches the passive diagnostic model. LSP diagnostics appear
    -- automatically — external linters should too. Fires after save and
    -- after opening a file. For filetypes with no linter configured,
    -- lint.try_lint() is a no-op (safe to call unconditionally).
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
      group = vim.api.nvim_create_augroup("UserLintOnSave", { clear = true }),
      callback = function()
        lint.try_lint()
      end,
      desc = "Run nvim-lint on file open and save",
    })
  end,
}
