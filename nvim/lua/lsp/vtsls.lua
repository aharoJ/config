-- path: nvim/lua/lsp/vtsls.lua
local M = {}

function M.setup(ctx)
	-- Prefer vtsls; fall back to typescript-language-server if needed
	local cmd = vim.fn.exepath("vtsls")
	if cmd == "" then
		cmd = vim.fn.exepath("typescript-language-server")
	end
	local server = cmd ~= "" and { cmd, "--stdio" } or nil

	vim.lsp.config("vtsls", {
		cmd = server,
		on_attach = function(client, bufnr)
			-- Let Prettier handle formatting
			client.server_capabilities.documentFormattingProvider = false
			client.server_capabilities.documentRangeFormattingProvider = false
			ctx.on_attach(client, bufnr)
		end,
		capabilities = ctx.capabilities,
		settings = {
			-- These apply for both JS & TS under vtsls
			typescript = {
				inlayHints = {
					parameterNames = { enabled = "literals" },
					parameterTypes = { enabled = true },
					variableTypes = { enabled = true },
					propertyDeclarationTypes = { enabled = true },
					functionLikeReturnTypes = { enabled = true },
					enumMemberValues = { enabled = true },
				},
				preferences = {
					importModuleSpecifier = "non-relative",
					quoteStyle = "auto",
					includePackageJsonAutoImports = "on",
				},
				suggest = { completeFunctionCalls = true },
				format = { enable = false }, -- Prettier rules.
			},
			javascript = {
				inlayHints = {
					parameterNames = { enabled = "literals" },
					parameterTypes = { enabled = true },
					variableTypes = { enabled = true },
					propertyDeclarationTypes = { enabled = true },
					functionLikeReturnTypes = { enabled = true },
					enumMemberValues = { enabled = true },
				},
				preferences = { importModuleSpecifier = "non-relative" },
				format = { enable = false },
			},
		},
	})
end

return M
