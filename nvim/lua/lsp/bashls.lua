-- path: nvim/lua/lsp/bashls.lua
local M = {}

function M.setup(ctx)
	local cmd = vim.fn.exepath("bash-language-server")
	if cmd == "" then
		if vim.fn.filereadable("/opt/homebrew/bin/bash-language-server") == 1 then
			cmd = "/opt/homebrew/bin/bash-language-server"
		elseif vim.fn.filereadable("/usr/local/bin/bash-language-server") == 1 then
			cmd = "/usr/local/bin/bash-language-server"
		end
	end
	if cmd == "" then
		return
	end

	vim.lsp.config("bashls", {
		cmd = { cmd, "start" },
		filetypes = { "sh" }, -- bashls targets POSIX shell/bash files
		on_attach = ctx.on_attach,
		capabilities = ctx.capabilities,
		settings = {
			bashIde = { globPattern = "**/*@(.sh|.bash|.inc|.command)" },
		},
	})
end

return M
