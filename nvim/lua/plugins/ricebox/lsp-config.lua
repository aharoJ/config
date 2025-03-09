-- /lua.plugins.ricebox.lsp-config
return {
  -- THESE PLUGINS CANNOT BE SEPARATED
  -- "williamboman/mason.nvim",
  -- "williamboman/mason-lspconfig.nvim",
  -- "neovim/nvim-lspconfig",
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
        ensure_installed = { "lua_ls", "rust_analyzer", "pyright", "ts_ls", "bashls" },
        automatic_installation = true,
      })
    end,
  },
  ------------------------------------------------------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "folke/neodev.nvim",
      { "mfussenegger/nvim-jdtls",           lazy = false }, -- JAVA *** REQUIRED ***
      { "Hoffs/omnisharp-extended-lsp.nvim", lazy = false }, -- C# *** REQUIRED ***
    },
    lazy = false,
    -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
    config = function()
      -------------------    DAP UI    ------------------------
      require("neodev").setup({
        library = { plugins = { "nvim-dap-ui" }, types = true },
      })
      -------------------        CONFIG STARTS HERE       ------------------------
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local lspconfig = require("lspconfig") -- lspconfig

      -------------------        TS | JS       ------------------------
      lspconfig.ts_ls.setup({
        capabilities = capabilities,
      })

      -------------------        HTML       ------------------------
      lspconfig.html.setup({
        capabilities = capabilities,
      })

      -------------------        TAILWINDCSS       ------------------------
      lspconfig.tailwindcss.setup({
        capabilities = capabilities,
      })

      -------------------        CSS       ------------------------
      lspconfig.stylelint_lsp.setup({
        capabilities = capabilities,
      })

      -------------------        XML       ------------------------
      lspconfig.lemminx.setup({
        capabilities = capabilities,
      })

      -------------------        MARKDOWN       ------------------------
      lspconfig.marksman.setup({
        capabilities = capabilities,
      })

      -------------------        PYTHON       ------------------------
      lspconfig.pyright.setup({
        capabilities = capabilities,
      })

      -------------------        LUA       ------------------------
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
      })

      -------------------        YAML       ------------------------
      lspconfig.yamlls.setup({
        capabilities = capabilities,
      })

      ---------------------        RUST       ------------------------
      lspconfig.rust_analyzer.setup({
        capabilities = capabilities,
      })

      ---------------------  C# OmniSharp Setup  ------------------------
      require("plugins.ricebox.omnisharp").setup(capabilities)

      -------------------        SWIFT       ------------------------
      lspconfig.sourcekit.setup({
        capabilities = capabilities,
        cmd = { "/Users/aharo/.local/share/nvim/swift-stuff/sourcekit-lsp/.build/release/sourcekit-lsp" },
        filetypes = { "swift", "c", "cpp", "objective-c", "objective-cpp" },
        root_dir = lspconfig.util.root_pattern("Package.swift", ".git"), -- or specify a fixed path
      })

      -------------------        BASH       ------------------------
      lspconfig.bashls.setup({
        capabilities = capabilities,
        cmd = { "bash-language-server", "start" },
        filetypes = { "sh", "bash" }, -- You can add more file types here if needed
      })

      -------------------        PHP       ------------------------
      lspconfig.intelephense.setup({
        capabilities = capabilities,
        root_dir = function(fname)
          -- return is VERY IMPORTANT
          return require("lspconfig").util.root_pattern("*.php", ".git")(fname) or vim.fn.getcwd()
        end,
      })

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
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { noremap = true, silent = true })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { noremap = true, silent = true })
      vim.keymap.set("n", "<space>co", vim.diagnostic.open_float, { noremap = true, silent = true })
      vim.keymap.set("n", "<space>cq", vim.diagnostic.setloclist, { noremap = true, silent = true })
      vim.keymap.set("n", "<space>ct", vim.lsp.buf.type_definition, { noremap = true, silent = true })
      -------------------        function       ------------------------
      vim.keymap.set("n", "<space>cwl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, { noremap = true, silent = true })
    end,
  },

  -- {
  --   "mfussenegger/nvim-jdtls", -- ***Java LSP***
  -- },
}
