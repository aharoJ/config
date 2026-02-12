-- path: nvim/lsp/basedpyright.lua
-- Description: Native 0.11+ config for basedpyright — Python type checker + LSP.
--              Sole Python LSP: types, hover, goto-def, references, rename,
--              completions, diagnostics. Formatting via ruff_format (conform).
-- CHANGELOG: 2026-02-12 | IDEI Phase F3. Python language expansion.
--            basedpyright as sole Python LSP. ruff dropped as LSP (overlap was
--            systemic and unsolvable without whack-a-mole suppressions).
--            ruff_format still handles formatting via conform.
--            | ROLLBACK: Delete file, remove "basedpyright" from ensure_installed

return {
  settings = {
    basedpyright = {
      -- ── Analysis ──────────────────────────────────────────────────
      -- WHY "standard": "basic" suppresses too many useful type errors.
      -- "strict" is noisy for a Spring Boot backend dev who uses Python
      -- for scripting/tooling, not as primary language. "standard" is the
      -- sweet spot — catches real bugs without drowning you in annotations.
      analysis = {
        typeCheckingMode = "standard",
      },
    },
  },

  -- ── Root Detection ──────────────────────────────────────────────────
  -- WHY explicit: monorepo safety. Default root detection can attach at
  -- the wrong level. pyproject.toml is the modern Python project marker.
  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "pyrightconfig.json",
    ".git",
  },
}
