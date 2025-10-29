-- path: nvim/lua/plugins/lsp/lsp.lua
return {
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            local lspconfig = require("lspconfig")
            local caps = vim.lsp.protocol.make_client_capabilities()
            local ok, cmp = pcall(require, "cmp_nvim_lsp")
            if ok then
                caps = cmp.default_capabilities(caps)
            end


            
            lspconfig.pyright.setup({ capabilities = caps }) -- python                 
            lspconfig.lua_ls.setup({capabilities = caps}) -- lua
            lspconfig.clangd.setup({ capabilities = caps, cmd = { "clangd", "--clang-tidy" } }) -- cpp
            lspconfig.html.setup({ capabilities = caps })    -- html
            lspconfig.fish_lsp.setup({ capabilities = caps }) --fish
            -- lspconfig..setup({ capabilities = caps }) -- NAME
        
    

            vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "[lsp] code action" })
        end,
    },
    {
        "mason-org/mason.nvim",
        config = function()
            require("mason").setup()
        end,
        -- opts={}, -- same as::above
    },
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            "mason-org/mason.nvim",
            "neovim/nvim-lspconfig", -- <- ensure lspconfig is available first (read docs)
        },
        config = function()
            require("mason-lspconfig").setup({
                -- ensure_installed = { "clangd"},
                ensure_installed = { "lua_ls", "ts_ls", "pyright" }, -- Add more as needed, e.g., "clangd"
                automatic_enable = {
                    automatic_enable = true,
                    exclude = { "jdtls" }, -- <- mason won’t touch JDTLS (future issue)
                },
            })
        end,
    },
}
