-- lua/plugins/ricebox.lua
return {
  require("plugins.ricebox.lsp-config"),        -- lsp configuration
  require("plugins.ricebox.debugging"),         -- debugging
  require("plugins.ricebox.none-ls"),           -- linting/formatting
  require("plugins.ricebox.toggle-diagnostics"), -- toggle lsp
  require("plugins.ricebox.autopair"),          -- pair ({[]})
  -- require("plugins.ricebox.jdtls"),             -- java lsp (we instead use it as a dependency)
  -- require("plugins.ricebox.omnisharp"),        --  c-sharp lsp (we instead use it as a dependency)
  -- require("plugins.ricebox."),
}
