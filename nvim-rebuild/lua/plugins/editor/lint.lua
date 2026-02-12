-- path: nvim/lua/plugins/editor/lint.lua
-- Description: nvim-lint — async linting engine. Auto-triggers on save and file open.
--              Linters run ALONGSIDE LSP diagnostics, not instead of them. For Lua,
--              lua_ls covers all diagnostics — no external linter needed.
-- CHANGELOG: 2026-02-11 | IDEI Phase D build. Empty linters_by_ft for Lua-only phase.
--            Auto-trigger on BufWritePost + BufReadPost (matches LSP diagnostic model).
--            | ROLLBACK: Delete file
--            2026-02-12 | IDEI Phase F6. Added markdownlint-cli2 for Markdown.
--            First real nvim-lint entry. markdownlint-cli2 checks style/convention rules
--            (heading hierarchy, line length, whitespace, etc.). marksman LSP handles
--            structural diagnostics (broken links, ambiguous references) — zero overlap.
--            Config via .markdownlint-cli2.yaml (searched up from file location).
--            | ROLLBACK: Remove markdown entry from linters_by_ft

return {
  "mfussenegger/nvim-lint",

  -- WHY BufReadPost + BufWritePost: Linting is passive like LSP diagnostics — you
  -- don't manually trigger lua_ls, so you shouldn't manually trigger eslint either.
  -- BufReadPost = lint when opening a file. BufWritePost = lint after saving.
  -- No BufReadPre — we lint AFTER the buffer is loaded, not during.
  event = { "BufReadPost", "BufWritePost" },

  opts = {
    -- ── Linters by Filetype ───────────────────────────────────────────────
    -- Each entry = exactly ONE linter per filetype. One tool per job.
    --
    -- Lua: lua_ls covers all diagnostics. No external linter.
    -- TypeScript/JavaScript: eslint runs as LSP (Phase F1), NOT here.
    -- Python: basedpyright covers diagnostics (Phase F3). No external linter.
    -- Bash: bashls auto-integrates shellcheck. DO NOT add here.
    -- Markdown: markdownlint-cli2 for style rules. marksman LSP handles link diagnostics.
    linters_by_ft = {
      markdown = { "markdownlint-cli2" },   -- Phase F6: style/convention linting
      -- python = { "ruff" },               -- DROPPED: basedpyright is sole Python LSP
      -- typescript = { "eslint" },          -- ESLint runs as LSP, not nvim-lint
      -- sh = { "shellcheck" },             -- bashls integrates shellcheck. DO NOT ADD.
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
