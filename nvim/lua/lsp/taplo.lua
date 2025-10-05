-- path: nvim/lua/lsp/taplo.lua
-- desc: TOML lsp 
local M = {}

function M.setup(ctx)
	-- Taplo LSP is provided by the taplo CLI: `taplo lsp stdio`
	local taplo = vim.fn.exepath("taplo")
	if taplo == "" then
		if vim.fn.filereadable("/opt/homebrew/bin/taplo") == 1 then
			taplo = "/opt/homebrew/bin/taplo"
		elseif vim.fn.filereadable("/usr/local/bin/taplo") == 1 then
			taplo = "/usr/local/bin/taplo"
		end
	end
	if taplo == "" then
		return
	end

	vim.lsp.config("taplo", {
		cmd = { taplo, "lsp", "stdio" },
		on_attach = ctx.on_attach,
		capabilities = ctx.capabilities,
		settings = {
			taplo = {
				-- Let Conform own formatting; LSP will still offer it but we "fallback" to LSP only if no CLI
				schema = { enabled = true },
			},
		},
	})
end

return M
