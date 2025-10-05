-- path: nvim/lua/lsp/cssls.lua
local M = {}

function M.setup(ctx)
	local cmd = vim.fn.exepath("vscode-css-language-server")
	if cmd == "" then
		cmd = "vscode-css-language-server"
	end

	vim.lsp.config("cssls", {
		cmd = { cmd, "--stdio" },
		on_attach = function(client, bufnr)
			-- Formatting via Prettier; keep hover/diags/rename/etc here
			client.server_capabilities.documentFormattingProvider = false
			ctx.on_attach(client, bufnr)
		end,
		capabilities = ctx.capabilities,
		settings = {
			css = { validate = true },
			scss = { validate = true },
			less = { validate = true },
		},
	})
end

return M
