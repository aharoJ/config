-- ~/.config/nvim/ftplugin/java.lua
local capabilities = require('cmp_nvim_lsp').default_capabilities()
local project_root = vim.fs.dirname(vim.fs.find({'gradlew', '.git', 'mvnw'}, { upward = true })[1])

local config_java = {
  cmd = {vim.fn.expand('~/.local/share/nvim/mason/bin/jdtls')},
  root_dir = project_root,
  capabilities = capabilities,
}

-- Optionally, you can set java-specific LSP keybindings here or in the config function

require('jdtls').start_or_attach(config_java)

-- Set Java-specific keybindings if desired
vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = 0 })
vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { buffer = 0 })
vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, { buffer = 0 })
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { buffer = 0 })


