-- path: nvim/lsp/marksman.lua
-- Description: Native 0.11+ config for marksman Markdown LSP. Auto-discovered by
--              vim.lsp.config() — no require() needed. Provides structural intelligence:
--              completion for links (wiki/inline/reference), goto definition, find references,
--              rename refactoring, document symbols (headings), code lens, TOC code action,
--              and diagnostics for broken/ambiguous link references.
--
--              marksman does NOT provide style linting (that's markdownlint-cli2 via nvim-lint)
--              and does NOT provide formatting (that's prettierd via conform, already Phase F1).
--
--              Requires .marksman.toml or git repo at project root for multi-file mode
--              (cross-file completion, references). Single-file mode works without.
--
-- CHANGELOG: 2026-02-12 | IDEI Phase F6. Minimal config — marksman has sane defaults.
--            Formatting disabled (prettierd handles it via conform).
--            | ROLLBACK: Delete file, remove "marksman" from ensure_installed in lsp.lua

return {
  -- ── Root Markers ────────────────────────────────────────────────────
  -- WHY explicit: marksman needs a project root to enable multi-file mode
  -- (cross-file completion, references, rename). Without these markers it
  -- falls back to single-file mode. .marksman.toml is the canonical marker;
  -- .git covers all git repos (which is everything in our workflow).
  root_markers = { ".marksman.toml", ".git" },

  -- ── Formatting Kill ─────────────────────────────────────────────────
  -- WHY: marksman doesn't actually provide formatting, but this is belt-and-
  -- suspenders consistency with every other lsp/<server>.lua in the IDEI stack.
  -- The LspAttach global kill in lsp.lua is the real safety net.
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
