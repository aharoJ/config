-- path: nvim/lua/lsp/eslint.lua
local M = {}

function M.setup(ctx)
	local cmd = vim.fn.exepath("vscode-eslint-language-server")
	if cmd == "" then
		cmd = "vscode-eslint-language-server"
	end

	vim.lsp.config("eslint", {
		cmd = { cmd, "--stdio" },
		on_attach = function(client, bufnr)
			ctx.on_attach(client, bufnr)
			-- We still use Conform+eslint_d for fix-on-save; LSP for diags & code actions.
			client.server_capabilities.documentFormattingProvider = false
			client.server_capabilities.documentRangeFormattingProvider = false
		end,
		capabilities = ctx.capabilities,
		settings = {
			eslint = {
				useFlatConfig = true, -- works w/ modern eslint.config.js
				workingDirectories = { mode = "auto" },
				codeAction = { disableRuleComment = { enable = true }, showDocumentation = { enable = true } },
				problems = { shortenToSingleLine = true },
			},
		},
	})
end

return M
