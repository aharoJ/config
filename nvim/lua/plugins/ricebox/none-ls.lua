-- path: nvim/lua/plugins/ricebox/none-ls.lua

-- diagnostic == linting
-- formatting == format
return {
	"nvimtools/none-ls.nvim", -- https://github.com/nvimtools/none-ls.nvim/blob/main/doc/BUILTINS.md
	dependencies = {
		"gbprod/none-ls-shellcheck.nvim", -- BASH
		"nvimtools/none-ls-extras.nvim", -- eslint_d --> TS/JS
	},
	config = function()
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

				-------------------        RUBY/RAILS       ------------------------
				null_ls.builtins.diagnostics.rubocop,
				null_ls.builtins.formatting.rubocop,

				-------------------        PHP       ------------------------
				null_ls.builtins.diagnostics.phpstan,
				null_ls.builtins.formatting.phpcsfixer,

				-------------------        FISH       ------------------------
				null_ls.builtins.diagnostics.fish,
        null_ls.builtins.formatting.fish_indent,

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
		-- vim.keymap.set("n", "<leader>cf", function()
		-- 	vim.lsp.buf.format({
		-- 		filter = function(client)
		-- 			-- Only use none-ls for formatting, ignore LSP formatters
		-- 			return client.name == "null-ls"
		-- 		end,
		-- 	})
		-- end, { desc = "Format with none-ls only" })

		-- vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, {})
	end,
}
