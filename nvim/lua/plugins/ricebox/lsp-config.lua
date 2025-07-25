-- path: nvim/lua/plugins/ricebox/lsp-config.lua
return {
  {
    "mfussenegger/nvim-jdtls", -- ***Java LSP***
  },
  {
    "mason-org/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup({
        ui = {
          check_outdated_packages_on_open = true,
          auto_update_packages = true,
        },
      })
    end,
  },

  {
    "mason-org/mason-lspconfig.nvim",
    lazy = false,
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {},      -- DEBUGGING
        -- ensure_installed = { "lua_ls", "rust_analyzer", "pyright", "ts_ls", "bashls" },
        automatic_installation = false, -- MUST BE FALSE [dup issue]
        automatic_setup = false,    -- Disable automatic server setup
        automatic_enable = false,   -- but never auto‑attaches
        handlers = nil,
      })
    end,
  },
  ------------------------------------------------------------------------------------------------
  {
    "neovim/nvim-lspconfig", -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
    dependencies = {
      { "folke/neodev.nvim" },
      -- { 'nvim-java/nvim-java' }, -- ITS NOT WORKING BUT JDTLS WORK IDK HOW
      -- { "Hoffs/omnisharp-extended-lsp.nvim", lazy = false }, -- C# *** REQUIRED *** -- DEBUGGING
    },
    lazy = false,
    config = function()
      -- Guard clause remains
      if vim.g.lsp_config_loaded then
        return
      end
      vim.g.lsp_config_loaded = true

      -------------------        CONFIG STARTS HERE       ------------------------
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local lspconfig = require("lspconfig")

      -- lspconfig.java.setup({
      --     capabilities = capabilities,
      -- })

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
      -- require("plugins.ricebox.omnisharp").setup(capabilities) -- DEBUGGIGN

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

      vim.keymap.set("n", "<leader>cS", vim.lsp.buf.signature_help, { desc = "" })
      vim.keymap.set("n", "<space>cwa", vim.lsp.buf.add_workspace_folder, { desc = "" })
      vim.keymap.set("n", "<space>cwr", vim.lsp.buf.remove_workspace_folder, { desc = "" })

      vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "[lsp] hover docs" })
      vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "[lsp] implementation" })
      vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "[lsp] references" })
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "[lsp] definition" })
      vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "[lsp] declaration" })
      vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { desc = "[lsp] rename symbol" })
      vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, { desc = "[lsp] signature help" })
      vim.keymap.set("n", "<space>gt", vim.lsp.buf.type_definition, { desc = "[lsp] type definition" })
      vim.keymap.set("n", "<leader>gs", vim.lsp.buf.document_symbol, { desc = "[lsp] doc syms" })
      vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "[lsp] code action" })

      -- Diagnostic navigation
      vim.keymap.set("n", "co", vim.diagnostic.open_float, { desc = "[diag] hover line" })
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "[diag] previous" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "[diag] next" })
      vim.keymap.set("n", "<leader>gl", vim.diagnostic.setloclist, { desc = "[diag] get diag loclist" })

      -------------------        function       ------------------------
      vim.keymap.set("n", "<space>cwl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, { desc = "" })

      -- toggle ALL diagnostics on/off
      vim.keymap.set("n", "<leader>td", function()
        vim.diagnostic.enable(not vim.diagnostic.is_enabled())
      end, { silent = true, noremap = true, desc = "[lsp] diag ON|OFF" })
    end,
  },
}
