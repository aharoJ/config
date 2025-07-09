-- path: nvim/lua/plugins/ricebox.lua
return {
    require("plugins.ricebox.lsp-config"),        -- lsp configuration
    require("plugins.ricebox.none-ls"),           -- linting/formatting
    require("plugins.ricebox.autopair"),          -- pair ({[]})
    --   require("plugins.ricebox.nvim-jdtls"),
    -- require("plugins.ricebox.nvim-java"),
}
