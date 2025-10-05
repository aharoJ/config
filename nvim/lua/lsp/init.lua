---@diagnostic disable: undefined-global
-- path: nvim/lua/plugins/lsp/init.lua

local M = {}

-- Diagnostics UI: quiet by default, floats on demand
vim.diagnostic.config({
	underline = true,
	virtual_text = false,
	severity_sort = true,
	update_in_insert = false,
	float = { border = "rounded", source = "if_many" },
	signs = true,
})

-- Signs
local signs = { Error = "", Warn = "", Hint = "", Info = "" }
for t, icon in pairs(signs) do
	local hl = "DiagnosticSign" .. t
	vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

-- Bordered hover/signature
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

-- Shared on_attach (just language features; no formatting/lint here)
local function bufmap(buf, mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
end

M.on_attach = function(_, bufnr)
	if vim.lsp.inlay_hint then
		pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
	end

	bufmap(bufnr, "n", "gd", vim.lsp.buf.definition, "LSP: Go to definition")
	bufmap(bufnr, "n", "gr", vim.lsp.buf.references, "LSP: References")
	bufmap(bufnr, "n", "gD", vim.lsp.buf.declaration, "LSP: Go to declaration")
	bufmap(bufnr, "n", "gi", vim.lsp.buf.implementation, "LSP: Implementation")
	bufmap(bufnr, "n", "K", vim.lsp.buf.hover, "LSP: Hover")
	bufmap(bufnr, "i", "<C-k>", vim.lsp.buf.signature_help, "LSP: Signature help")
	bufmap(bufnr, "n", "<leader>rn", vim.lsp.buf.rename, "LSP: Rename symbol")
	-- bufmap(bufnr, "n", "<leader>ca", vim.lsp.buf.code_action, "LSP: Code action")
	bufmap(bufnr, "n", "<leader>co", vim.diagnostic.open_float, "Diagnostics: Line")
	bufmap(bufnr, "n", "[d", vim.diagnostic.goto_prev, "Diagnostics: Prev")
	bufmap(bufnr, "n", "]d", vim.diagnostic.goto_next, "Diagnostics: Next")

	-- existing
	bufmap(bufnr, "n", "<leader>ca", vim.lsp.buf.code_action, "LSP: Code action")

	-- add visual-mode mapping for range code actions
	bufmap(bufnr, "v", "<leader>ca", vim.lsp.buf.code_action, "LSP: Code action (range)")

	-- optional: quick-apply if only one action
	bufmap(bufnr, "n", "<leader>cA", function()
		vim.lsp.buf.code_action({ apply = true })
	end, "LSP: Code action (auto-apply single)")
end

-- Stock capabilities (we’ll augment later when we add completion)
M.capabilities = vim.lsp.protocol.make_client_capabilities()

function M.setup()
	require("lsp.lua_ls").setup(M)
	require("lsp.pyright").setup(M)
	require("lsp.ruff").setup(M) -- NEW
	require("lsp.servers").enable()
	require("lsp.taplo").setup(M)
	require("lsp.yamlls").setup(M)
	require("lsp.bashls").setup(M)
	require("lsp.fish").setup(M)
	require("lsp.marksman").setup(M) -- ← add this
end

return M
