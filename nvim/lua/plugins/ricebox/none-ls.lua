-- diagnostic == linting
-- formatting == format
return {
	"nvimtools/none-ls.nvim",
	dependencies = {
		"gbprod/none-ls-shellcheck.nvim", -- shellcheck
		"nvimtools/none-ls-extras.nvim", -- eslint_d --> TS/JS
	},
	config = function()
		-- https://github.com/nvimtools/none-ls.nvim/blob/main/doc/BUILTINS.md
		local null_ls = require("null-ls")
		null_ls.setup({
			sources = {
				-------------------        JAVA       ------------------------
				-- REFERENCE ftplugin/java.lua

				-------------------        LUA       ------------------------
				null_ls.builtins.formatting.stylua,

				-------------------        BASH       ------------------------
				null_ls.builtins.formatting.shfmt,
				require("none-ls-shellcheck.diagnostics"),
				require("none-ls-shellcheck.code_actions"),

				-------------------        TS | JS       ------------------------
				require("none-ls.diagnostics.eslint_d"),
				require("none-ls.code_actions.eslint_d"),

				-------------------        GO       ------------------------
				null_ls.builtins.diagnostics.staticcheck,
				null_ls.builtins.formatting.asmfmt,

				-------------------        PHP       ------------------------
				null_ls.builtins.diagnostics.phpstan,
				null_ls.builtins.formatting.phpcsfixer,

				-------------------        FISH       ------------------------
				null_ls.builtins.diagnostics.fish,

				-------------------        PYTHON       ------------------------
				null_ls.builtins.formatting.black,

				-----------------        XML       ------------------------
				null_ls.builtins.formatting.tidy.with({
					filetypes = { "xml" },
				}), -- formatter
				null_ls.builtins.diagnostics.tidy.with({
					filetypes = { "xml" },
				}), -- linter

				-------------------        SQL       ------------------------
				null_ls.builtins.formatting.pg_format,

				-------------------        C#        ------------------------
				null_ls.builtins.formatting.csharpier,
				-- dont think there is a linter?

				-------------------        PRETTIER FORMATTER       ------------------------
				null_ls.builtins.formatting.prettierd,
				-- null_ls.builtins.formatting.prettier, // more popular
			},
		})

		vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, {})
	end,
}
