-- path: nvim/lua/lsp/yamlls.lua
local M = {}

function M.setup(ctx)
	local cmd = vim.fn.exepath("yaml-language-server")
	if cmd == "" then
		if vim.fn.filereadable("/opt/homebrew/bin/yaml-language-server") == 1 then
			cmd = "/opt/homebrew/bin/yaml-language-server"
		elseif vim.fn.filereadable("/usr/local/bin/yaml-language-server") == 1 then
			cmd = "/usr/local/bin/yaml-language-server"
		end
	end
	if cmd == "" then
		return
	end

	local has_ss, schemastore = pcall(require, "schemastore")

	vim.lsp.config("yamlls", {
		cmd = { cmd, "--stdio" },
		on_attach = ctx.on_attach,
		capabilities = ctx.capabilities,
		settings = {
			yaml = {
				validate = true,
				keyOrdering = false,
				format = { enable = false }, -- we format via Conform (yamlfmt/prettier)
				schemaStore = { enable = not has_ss, url = "https://www.schemastore.org/api/json/catalog.json" },
				schemas = has_ss and schemastore.yaml.schemas() or {},
			},
			redhat = { telemetry = { enabled = false } },
		},
	})
end

return M
