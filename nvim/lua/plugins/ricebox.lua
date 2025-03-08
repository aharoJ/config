-- lua/plugins/ricebox.lua
return {
  require("plugins.ricebox.lsp-config"),        -- lsp configuration
  require("plugins.ricebox.debugging"),         -- debugging
  require("plugins.ricebox.none-ls"),           -- linting/formatting
  require("plugins.ricebox.toggle-diagnostics"), -- toggle lsp
  require("plugins.ricebox.autopair"),          -- pair ({[]})
  require("plugins.ricebox.jdtls"),             -- java lsp
  require("plugins.ricebox.csharp-lsp"),        --  c-sharp lsp
  -- require("plugins.ricebox."),
}
