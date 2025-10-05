-- WHAT IS THIS?
-- path: nvim/lua/lsp/emmet.lua
local M = {}

function M.setup(ctx)
	local cmd = vim.fn.exepath("emmet-language-server")
	if cmd == "" then
		cmd = "emmet-language-server"
	end

	vim.lsp.config("emmet_ls", {
		cmd = { cmd, "--stdio" },
		filetypes = { "html", "css", "scss", "sass", "less", "javascriptreact", "typescriptreact" },
		init_options = { showExpandedAbbreviation = "always" },
		on_attach = ctx.on_attach,
		capabilities = ctx.capabilities,
	})
end

return M
