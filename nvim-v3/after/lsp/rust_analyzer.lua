-- path: ~/.config/nvim-v3/after/lsp/rust_analyzer.lua
-- description: Rust analyzer — basic config (no rustaceanvim)
-- patched: Phase 3 (D24)
return {
  root_markers = { "Cargo.toml", ".git" },
  settings = {
    ["rust-analyzer"] = {
      check = { command = "clippy" },
      cargo = { allFeatures = true },
      procMacro = { enable = true },
      inlayHints = {
        closingBraceHints = { minLines = 25 },
      },
    },
  },
}
