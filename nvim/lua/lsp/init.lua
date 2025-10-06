-- path: nvim/lua/plugins/lsp/init.lua
---@diagnostic disable: undefined-global

local M = {}

M.on_attach = function(_, bufnr)
    -- Inlay hints (0.11+)
    if vim.lsp.inlay_hint and vim.lsp.inlay_hint.enable then
        pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
    end

    -- ──────────────────────────────────────────────────────────────
    -- lsp mappings 
    -- ──────────────────────────────────────────────────────────────
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr, silent = true, desc = "LSP: Go to definition" })
    vim.keymap.set("n", "gr", vim.lsp.buf.references, { buffer = bufnr, silent = true, desc = "LSP: References" })
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, silent = true, desc = "LSP: Go to declaration" })
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { buffer = bufnr, silent = true, desc = "LSP: Implementation" })
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { buffer = bufnr, silent = true, desc = "LSP: Rename symbol" })
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { buffer = bufnr, silent = true, desc = "LSP: Code action" })
    vim.keymap.set("v", "<leader>ca", vim.lsp.buf.code_action, { buffer = bufnr, silent = true, desc = "LSP: Code action (range)" })
    vim.keymap.set("n", "<leader>cA", function() vim.lsp.buf.code_action({ apply = true }) end, { buffer = bufnr, silent = true, desc = "LSP: Code action (auto-apply single)" })
    vim.keymap.set("n", "K", function() vim.lsp.buf.hover({ border = "rounded" }) end, { buffer = bufnr, silent = true, desc = "LSP: Hover" })
    vim.keymap.set("i", "<C-k>", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, { buffer = bufnr, silent = true, desc = "LSP: Signature help" })
end

-- Capabilities (augment later if you use cmp_nvim_lsp)
M.capabilities = vim.lsp.protocol.make_client_capabilities()

function M.setup()
    require("lsp.lua_ls").setup(M)
    require("lsp.pyright").setup(M)
    require("lsp.ruff").setup(M)
    require("lsp.servers").enable()
    require("lsp.taplo").setup(M)
    require("lsp.yamlls").setup(M)
    require("lsp.bashls").setup(M)
    require("lsp.fish").setup(M)
    require("lsp.marksman").setup(M)
end

return M
