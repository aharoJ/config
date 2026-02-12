-- path: nvim/lsp/bashls.lua
-- Description: Native 0.11+ config for bash-language-server. Auto-discovered
--              by vim.lsp.config() — no require() needed.
--
-- WHAT THIS DOES:
--   Diagnostics:  bashls + shellcheck (auto-integrated, 500ms debounce)
--   Completion:   blink.cmp ← bashls (builtins, functions, variables)
--   Formatting:   KILLED here — conform.nvim owns formatting (shfmt CLI)
--   Hover:        bashls (man page documentation for commands)
--   Goto Def:     bashls (jump to function definitions, sourced files)
--   Code Actions: shellcheck quick-fixes via bashls
--
-- CRITICAL: bashls auto-integrates shellcheck when it's on $PATH.
--   DO NOT add shellcheck to nvim-lint — that causes duplicate diagnostics
--   (Anti-pattern #18 in IDEI tracker). bashls is the SOLE diagnostic source
--   for sh/bash files.
--
-- CHANGELOG: 2026-02-12 | IDEI Phase F11 build. Bash language expansion.
--            bashls + shellcheck (auto-integrated), shfmt via conform.
--            | ROLLBACK: Delete file, remove "bashls" from ensure_installed in lsp.lua,
--            remove sh/bash entries from formatting.lua

return {
  -- ── Root Detection ──────────────────────────────────────────────────────
  -- WHY: Shell scripts often live standalone or in utility directories.
  -- .git is the only reliable marker. single_file_support (from nvim-lspconfig
  -- defaults) handles scripts opened outside any project.
  root_markers = { ".git" },

  -- ── Server Settings ─────────────────────────────────────────────────────
  settings = {
    bashIde = {
      -- WHY: Default glob pattern prevents recursive scanning when opening a
      -- file directly in the home directory (e.g. ~/setup.sh). The upstream
      -- default "*@(.sh|.inc|.bash|.command)" is safe — don't use "**/*"
      -- which would recursively scan everything.
      globPattern = "*@(.sh|.inc|.bash|.command)",

      -- WHY: shellcheck is the gold standard for shell script linting.
      -- bashls auto-detects shellcheck on $PATH and runs it with 500ms
      -- debounce on every file update. This gives us:
      --   - Lint diagnostics (SC2086 word splitting, SC2034 unused vars, etc.)
      --   - Code actions (quick-fixes for common issues)
      --   - Proper dialect detection (bash vs sh vs dash)
      -- Default "shellcheck" — just ensure it's installed.
      shellcheckPath = "shellcheck",
    },
  },

  -- ── Formatting Kill ─────────────────────────────────────────────────────
  -- WHY: bashls has built-in shfmt integration (documentFormatting provider).
  -- We KILL it because:
  --   1. Manual-only formatting — conform.nvim is the sole formatting authority
  --   2. One tool per job — shfmt runs through conform CLI, not bashls LSP
  --   3. Consistent pattern — every language except XML (lemminx) routes
  --      formatting through conform
  -- Without this kill, <leader>cf would trigger shfmt through BOTH conform
  -- AND the LSP fallback, potentially causing double-formatting.
  on_attach = function(client, _bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
