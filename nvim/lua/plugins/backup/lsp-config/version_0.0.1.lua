return {
  {
    "WhoIsSethDaniel/toggle-lsp-diagnostics.nvim",
    config= function ()
    require('toggle_lsp_diagnostics').init()
    vim.api.nvim_set_keymap('n', '<leader>ct', '<Plug>(toggle-lsp-diag)', { noremap = true, silent = true })
    -- vim.api.nvim_set_keymap('n', '<leader>ctu', '<Plug>(toggle-lsp-diag-underline)', { noremap = true, silent = true })
    -- vim.api.nvim_set_keymap('n', '<leader>cts', '<Plug>(toggle-lsp-diag-signs)', { noremap = true, silent = true })
    -- vim.api.nvim_set_keymap('n', '<leader>ctv', '<Plug>(toggle-lsp-diag-vtext)', { noremap = true, silent = true })
    -- vim.api.nvim_set_keymap('n', '<leader>ctp', '<Plug>(toggle-lsp-diag-update_in_insert)', { noremap = true, silent = true })
    -- vim.api.nvim_set_keymap('n', '<leader>tldd', '<Plug>(toggle-lsp-diag-default)', { noremap = true, silent = true })
    end
  },
  {
    "mfussenegger/nvim-jdtls",
  },
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "rust_analyzer" },
        automatic_installation = true,
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local lspconfig = require("lspconfig")
      lspconfig.tsserver.setup({
        capabilities = capabilities,
      })
      lspconfig.html.setup({
        capabilities = capabilities,
      })
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
      })
      lspconfig.yamlls.setup({
        capabilities = capabilities,
      })
      -- lspconfig.jdtls.setup({
      --   capabilities = capabilities
      -- })
      vim.keymap.set("n", "K", vim.lsp.buf.hover, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>cd", vim.lsp.buf.definition, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>cD", vim.lsp.buf.declaration, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>cr", vim.lsp.buf.references, { noremap = true, silent = true })
      vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>ci", vim.lsp.buf.implementation, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>cS", vim.lsp.buf.signature_help, { noremap = true, silent = true })
      vim.keymap.set("n", "<space>cwa", vim.lsp.buf.add_workspace_folder, { noremap = true, silent = true })
      vim.keymap.set("n", "<space>cwr", vim.lsp.buf.remove_workspace_folder, { noremap = true, silent = true })
      vim.keymap.set("n", "<space>cR", vim.lsp.buf.rename, { noremap = true, silent = true })
      vim.keymap.set("n", "<space>cwl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, { noremap = true, silent = true })
      --
      vim.keymap.set("n", "<space>cf", function()
        vim.lsp.buf.format({ async = true })
      end, { noremap = true, silent = true })
    end,
  },
}

-- -- Global mappings.
-- -- See `:help vim.diagnostic.*` for documentation on any of the below functions
-- vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
-- vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
-- vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
-- vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)
--
-- -- Use LspAttach autocommand to only map the following keys
-- -- after the language server attaches to the current buffer
-- vim.api.nvim_create_autocmd('LspAttach', {
--   group = vim.api.nvim_create_augroup('UserLspConfig', {}),
--   callback = function(ev)
--     -- Enable completion triggered by <c-x><c-o>
--     vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
--
--     -- Buffer local mappings.
--     -- See `:help vim.lsp.*` for documentation on any of the below functions
--     local opts = { buffer = ev.buf }
--     vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
--     vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
--     vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
--     vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
--     vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
--     vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
--     vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
--     vim.keymap.set('n', '<space>wl', function()
--       print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
--     end, opts)
--     vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
--     vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
--     vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
--     vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
--     vim.keymap.set('n', '<space>f', function()
--       vim.lsp.buf.format { async = true }
--     end, opts)
