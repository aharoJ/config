-- path: ~/.config/nvim-v3/after/lsp/basedpyright.lua
-- description: Python type checker
-- patched: Phase 3 (D24)
return {
  root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", "pyrightconfig.json", ".git" },
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "standard",
      },
    },
  },
}
