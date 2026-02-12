-- path: nvim/lsp/taplo.lua
-- Description: Native 0.11+ config for taplo (TOML Language Server).
--              Auto-discovered by vim.lsp.config(). Provides diagnostics,
--              completion, hover, and schema validation for TOML files.
--
--              Covers: Cargo.toml, pyproject.toml, taplo.toml, stylua.toml,
--              starship.toml, and any other TOML config file.
--
--              Formatting routed through conform.nvim (taplo CLI), NOT LSP.
--              Manual-only via <leader>cf — consistent with all other languages.
--
-- CHANGELOG: 2026-02-12 | IDEI Phase F9 build. TOML language expansion.
--            | ROLLBACK: Delete file, remove "taplo" from ensure_installed in lsp.lua,
--            remove toml entry from formatting.lua
return {
  -- ── Root Detection ──────────────────────────────────────────────────
  -- WHY: TOML files appear in many contexts. Cargo.toml, pyproject.toml,
  -- and taplo.toml are the strongest project markers. .git catches everything.
  root_markers = { "taplo.toml", ".taplo.toml", "Cargo.toml", "pyproject.toml", ".git" },

  -- ── Formatting Kill ─────────────────────────────────────────────────
  -- WHY: taplo has built-in formatting via LSP, but we route ALL formatting
  -- through conform.nvim for manual-only trigger. Killing the LSP formatting
  -- capability ensures <leader>cf always goes through conform → taplo CLI,
  -- not through vim.lsp.buf.format(). One tool per job.
  on_attach = function(client, _bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
