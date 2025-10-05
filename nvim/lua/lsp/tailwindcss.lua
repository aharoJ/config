-- path: nvim/lua/lsp/tailwindcss.lua
local M = {}

function M.setup(ctx)
	local cmd = vim.fn.exepath("tailwindcss-language-server")
	if cmd == "" then
		cmd = "tailwindcss-language-server"
	end

	vim.lsp.config("tailwindcss", {
		cmd = { cmd, "--stdio" },
		on_attach = ctx.on_attach,
		capabilities = ctx.capabilities,
		settings = {
			tailwindCSS = {
				validate = true,
				experimental = {
					-- Recognize common helpers in Next.js apps
					classRegex = {
						"clsx\\(([^)]*)\\)",
						"classnames\\(([^)]*)\\)",
						"cva\\(([^)]*)\\)",
						"cn\\(([^)]*)\\)",
					},
				},
				includeLanguages = {
					typescriptreact = "html",
					javascriptreact = "html",
				},
				lint = {
					cssConflict = "warning",
					invalidApply = "error",
					invalidScreen = "error",
					invalidVariant = "error",
					recommendedVariantOrder = "warning",
				},
			},
		},
	})
end

return M
