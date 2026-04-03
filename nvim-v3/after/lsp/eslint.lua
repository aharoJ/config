-- path: ~/.config/nvim-v3/after/lsp/eslint.lua
-- description: ESLint as LSP — linting + code actions for JS/TS
-- patched: Phase 3 (D24, D26)
return {
  root_markers = {
    "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs",
    "eslint.config.ts", "eslint.config.mts",
    ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.yaml", ".eslintrc.yml", ".eslintrc.json",
    "package.json",
  },
  settings = {
    eslint = {
      validate = "on",
      workingDirectories = { mode = "auto" },
      codeActionOnSave = { enable = false },
      codeAction = {
        disableRuleComment = { enable = true, location = "separateLine" },
        showDocumentation = { enable = true },
      },
    },
  },
}
