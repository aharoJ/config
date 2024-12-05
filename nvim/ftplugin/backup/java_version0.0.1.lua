-- CODE from 3 years ago 

local config = {
  -- cmd = {'/Users/aharo/.local/share/nvim/mason/bin/jdtls'},
  cmd = {vim.fn.expand('~/.local/share/nvim/mason/bin/jdtls')},
  root_dir = vim.fs.dirname(vim.fs.find({'gradlew', '.git', 'mvnw'}, { upward = true })[1]),
}
require('jdtls').start_or_attach(config)

-- -- decapricated or whoever its spelled
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

-- local capabilities = require('cmp_nvim_lsp').default_capabilities()

local workspace_dir = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')

local config = {
  cmd = {
    'java',
    '-Declipse.application=org.eclipse.jdt.ls.core.id1 ',
    '-Dosgi.bundles.defaultStartLevel=4 ',
    '-Declipse.product=org.eclipse.jdt.ls.core.product ',
    '-Dlog.level=ALL ',
    '-Xmx1G ',
    '-jar',
    '/Library/Java/jdt-language-server-1.33.0-202402151717/pluginsorg.eclipse.equinox.launcher_1.6.700.v20231214-2017.jar',
    '-configuration', '/Library/Java/jdt-language-server-1.33.0-202402151717/config_mac/',
    '-data', vim.fn.expand('~/.cache/jdtls-workspace') .. workspace_dir
  },

  root_dir = vim.fs.dirname(vim.fs.find({ 'gradlew', '.git', 'mvnw' }, { upward = true })[1]),
  capabilities = capabilities,
}
require('jdtls').start_or_attach(config)

local opts = { noremap = true, silent = true }
vim.api.nvim_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
vim.api.nvim_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
vim.api.nvim_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
vim.api.nvim_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
vim.api.nvim_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
vim.api.nvim_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
vim.api.nvim_set_keymap('n', '<leader>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
vim.api.nvim_set_keymap('n', '<leader>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
vim.api.nvim_set_keymap('n', '<leader>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
vim.api.nvim_set_keymap('n', '<leader>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
vim.api.nvim_set_keymap('n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
vim.api.nvim_set_keymap('n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
vim.api.nvim_set_keymap('n', 'ge', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
vim.api.nvim_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
vim.api.nvim_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
vim.api.nvim_set_keymap('n', '<leader>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
vim.api.nvim_set_keymap('n', '<leader>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)

vim.api.nvim_set_keymap('n', '<leader>lA', '<cmd>lua require(\'jdtls\').code_action()<CR>', { silent = true })




-------------------     REQUIRE CLIENT    ------------------------
-- -- ERROR: https://github.com/mfussenegger/nvim-jdtls/blob/master/lua/jdtls/dap.lua
-- require("jdtls").test_class()
-- require("jdtls").test_nearest_method()
-- vim.keymap.set("n", "<leader>dZ", function()
--   require("jdtls").test_class()
-- end, { silent = true })
-- vim.keymap.set("n", "<leader>dn", function()
--   require("jdtls").test_nearest_method()
-- end, { silent = true })
----------------                                ----------------

-------------------    RUNS PROJECT ------------------------
vim.cmd([[
function! CompileAndRunJavaPackage()
    let l:current_file = expand('%')
    let l:package_directory = expand('%:p:h')
    let l:parent_directory = fnamemodify(l:package_directory, ':h')
    " Compile all Java files in the current package directory
    let compile_command = '!javac ' . l:package_directory . '/*.java'
    execute compile_command
    " Determine the package name by extracting the relative path and replacing slashes with dots
    let l:package_name = substitute(l:package_directory, l:parent_directory.'/', '', '')
    let l:package_name = substitute(l:package_name, '/', '.', 'g')
    " Extract the class name from the current file name
    let l:class_name = fnamemodify(l:current_file, ':t:r')
    " Concatenate to form the fully qualified class name
    let l:full_class = l:package_name . '.' . l:class_name
    " Run the compiled class without opening a new buffer or window
    let run_command = '!java -cp ' . l:parent_directory . ' ' . l:full_class
    execute run_command
endfunction
]])

vim.api.nvim_set_keymap("n", "<Space>rp", ":call CompileAndRunJavaPackage()<CR>", { noremap = true, silent = true })
----------------                              ----------------

-------------------    RUNS FILE    ------------------------
vim.api.nvim_set_keymap(
  "n",
  "<Space>rf",
  ':w!<CR>:!javac % && echo "" && echo "OUTPUT:" && java %<CR>',
  { noremap = true, silent = true }
)
----------------                              ---------------- 
