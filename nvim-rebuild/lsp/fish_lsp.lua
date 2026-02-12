-- path: nvim/lsp/fish_lsp.lua
-- Description: Native 0.11+ config for fish_lsp (Fish Shell Language Server).
--              Auto-discovered by vim.lsp.config(). Provides diagnostics,
--              completion, hover, go-to-definition, and scope-aware symbol analysis.
--
--              Formatting routed through conform.nvim (fish_indent CLI), NOT LSP.
--              fish_indent ships with fish shell itself — no separate install needed.
--              Manual-only via <leader>cf — consistent with all other languages.
--
--              NOTE: fish_lsp is installed via Mason (:MasonInstall fish-lsp).
--              fish_indent is NOT a Mason package — it's available because fish
--              shell is already installed as the user's shell (/opt/homebrew/bin/fish).
--
-- CHANGELOG: 2026-02-12 | IDEI Phase F10 build. Fish shell language expansion.
--            | ROLLBACK: Delete file, remove "fish_lsp" from ensure_installed in lsp.lua,
--            remove fish entry from formatting.lua
return {
  -- ── Root Detection ──────────────────────────────────────────────────────
  -- WHY: Fish configs live in ~/.config/fish/. config.fish is the primary
  -- entry point. conf.d/ holds modular configs. functions/ holds autoloaded
  -- functions. .git catches everything else for standalone fish scripts.
  root_markers = { "config.fish", ".git" },

  -- ── Formatting Kill ─────────────────────────────────────────────────────
  -- WHY: Even if fish_lsp adds formatting support in the future, we route
  -- ALL formatting through conform.nvim (fish_indent CLI) for manual-only
  -- trigger. Defensive kill ensures one tool per job.
  on_attach = function(client, _bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
