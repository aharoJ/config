-- path: ~/.config/nvim-v3/after/lsp/lemminx.lua
-- description: XML language server — keeps formatting (only XML formatter)
-- patched: Phase 3 (D24, D27)
return {
  root_markers = { "pom.xml", ".git" },
  init_options = {
    settings = {
      xml = {
        format = {
          enabled = true, -- lemminx IS the formatter for XML (D27 exemption)
          splitAttributes = true,
          joinContentLines = false,
          preservedNewlines = 2,
          insertFinalNewline = true,
        },
        validation = { enabled = true },
        completion = { autoCloseTag = true },
      },
    },
  },
}
