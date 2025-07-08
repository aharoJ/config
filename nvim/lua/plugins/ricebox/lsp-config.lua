-- path: nvim/lua/plugins/ricebox/lsp-config.lua
return {
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
            { "folke/neodev.nvim" },
            -- { 'nvim-java/nvim-java' }, -- ITS NOT WORKING BUT JDTLS WORK IDK HOW 
            { "Hoffs/omnisharp-extended-lsp.nvim", lazy = false }, -- C# *** REQUIRED ***
        },
        lazy = false,
        -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
        config = function()
            -------------------    DAP UI    ------------------------
            -- require("neodev").setup({
            --     library = { plugins = { "nvim-dap-ui" }, types = true },
            -- })
            -------------------        CONFIG STARTS HERE       ------------------------
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            local lspconfig = require("lspconfig") -- lspconfig


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

            vim.keymap.set("n", "<leader>cS", vim.lsp.buf.signature_help, { desc = "" })
            vim.keymap.set("n", "<space>cwa", vim.lsp.buf.add_workspace_folder, { desc = "" })
            vim.keymap.set("n", "<space>cwr", vim.lsp.buf.remove_workspace_folder, { desc = "" })
            vim.keymap.set("n", "<space>ct", vim.lsp.buf.type_definition, { desc = "" })
            vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "[lsp] hover docs" })
            vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, { desc = "[lsp] code action" })

            vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "[lsp] references" })
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "[lsp] definition" })
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "[lsp] declaration" })
            vim.keymap.set('n', '<leader>cr', vim.lsp.buf.rename, {desc='[lsp] rename symbol'})
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "[lsp] implementation" })
            
            vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, {desc='[lsp] signature help'})

            vim.keymap.set("n", "<space>gt", vim.lsp.buf.type_definition, { desc = "[lsp] type definition" })
            vim.keymap.set("n", "<leader>gs", vim.lsp.buf.document_symbol, { desc = "[lsp] doc syms" })


            -- Diagnostic navigation
            vim.keymap.set("n", "co", vim.diagnostic.open_float, { desc = "[diag] hover line" })
            vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "[diag] previous" })
            vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "[diag] next" })
            -- vim.keymap.set("n", "<leader>cq", vim.diagnostic.setloclist, { desc = "IN TELESCOPE "})

            -------------------        function       ------------------------
            vim.keymap.set("n", "<space>cwl", function()
                print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end, { desc = "" })
        end,
    },
}
