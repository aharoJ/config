-- path: nvim/lua/plugins/editor/lint.lua
-- Description: nvim-lint — async external linter runner. Fills gaps where LSPs don't lint.
--              Most linting comes from LSP servers (ts_ls, lua_ls, etc.). This plugin is for
--              tools that ONLY exist as standalone linters: checkstyle, markdownlint, shellcheck.
--              Results appear as native vim.diagnostic entries — no separate UI needed.
-- CHANGELOG: 2026-02-03 | Initial Phase 2 build. Minimal config — add linters as needed.
--            | ROLLBACK: Delete file

return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },

  config = function()
    local lint = require("lint")

    -- ── Linters by Filetype ─────────────────────────────────────────────
    -- WHY sparse: Most linting is handled by LSP servers already:
    --   • TypeScript/JavaScript → ts_ls + eslint LSP
    --   • Lua → lua_ls
    --   • Java → jdtls
    --   • JSON → jsonls
    -- Only add a linter here if the LSP doesn't cover it or you need a SPECIFIC
    -- standalone tool. Uncomment as you discover gaps in your workflow.
    lint.linters_by_ft = {
      -- markdown = { "markdownlint" },
      -- sh = { "shellcheck" },
      -- java = { "checkstyle" },        -- If jdtls diagnostics aren't enough
      -- dockerfile = { "hadolint" },
      -- yaml = { "yamllint" },
    }

    -- ── Auto-Lint on Save and Insert Leave ──────────────────────────────
    -- WHY BufWritePost + InsertLeave: Lint after saving (catch issues before commit) and
    -- after leaving insert mode (catch issues while editing). BufReadPost for initial open.
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("UserNvimLint", { clear = true }),
      desc = "Run linters via nvim-lint",
      callback = function()
        -- Only lint if there are linters configured for this filetype
        local ft = vim.bo.filetype
        if lint.linters_by_ft[ft] then
          lint.try_lint()
        end
      end,
    })
  end,
}
