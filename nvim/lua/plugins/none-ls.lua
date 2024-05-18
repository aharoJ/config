return {
	"nvimtools/none-ls.nvim",
	dependencies = {
		"gbprod/none-ls-shellcheck.nvim", -- shellcheck
		"nvimtools/none-ls-extras.nvim", -- eslint_d
	},
	config = function()
		-- https://github.com/nvimtools/none-ls.nvim/blob/main/doc/BUILTINS.md
		local null_ls = require("null-ls")
		null_ls.setup({
			sources = {
				-------------------        JAVA       ------------------------
				-- formatting -- ***WE USE FTPLUGIN/JAVA.LUA***
				--  diagnostics -- ***WE USE FTPLUGIN/JAVA.LUA***
				----------------                              ----------------

				-------------------        LUA       ------------------------
				null_ls.builtins.formatting.stylua,
				-- null_ls.builtins.diagnostics.selene,
				--  diagnostics -- ***WE USE lua_ls**
				----------------                              ----------------

				-------------------        BASH       ------------------------
				null_ls.builtins.formatting.shfmt,
				require("none-ls-shellcheck.diagnostics"),
				require("none-ls-shellcheck.code_actions"),
				----------------                              ----------------

				-------------------        TS | JS       ------------------------
				-- formatting: PRETTIER FORMATTER
				require("none-ls.diagnostics.eslint_d"), -- TS | JS
				require("none-ls.code_actions.eslint_d"),
				-- require("none-ls.formatting.beautysh"),
				-- require("none-ls.formatting.eslint_d"),
				-- require("none-ls.formatting.jq"),
				----------------                              ----------------

				-------------------        HTML       ------------------------
				-- null_ls.builtins.diagnostics.markuplint, -- TOO MANY ISSUES!!!!!!!!!!!
				----------------                              ----------------

				-------------------        CSS       ------------------------
				null_ls.builtins.diagnostics.stylelint, -- CSS
				----------------                              ----------------

				-------------------        GO       ------------------------
				null_ls.builtins.diagnostics.staticcheck,
				null_ls.builtins.formatting.asmfmt,
				----------------                              ----------------

				-------------------        PHP       ------------------------
				null_ls.builtins.diagnostics.phpstan,
				null_ls.builtins.formatting.phpcsfixer,
				----------------                              ----------------

				-------------------        RUST       ------------------------
				-- null_ls.builtins.formatting.rustfmt,
				-- null_ls.builtins.diagnostics.clippy,
				----------------                              ----------------

				-------------------        FISH       ------------------------
				null_ls.builtins.diagnostics.fish,
				----------------                              ----------------

				-------------------        PYTHON       ------------------------
				null_ls.builtins.formatting.black,
				-- null_ls.builtins.formatting.isort,
				-- null_ls.builtins.diagnostics.flake8,
				----------------                              ----------------

				-----------------        XML       ------------------------
				null_ls.builtins.formatting.tidy.with({
					filetypes = { "xml" },
				}),
				null_ls.builtins.diagnostics.tidy.with({
					filetypes = { "xml" },
				}),
				----------------                              ----------------
				----------------                              ----------------

				-------------------        SQL       ------------------------
				-- null_ls.builtins.formatting.sql_formatter, -- WORKS BUT NO LSP ELSE BREAKS
				null_ls.builtins.formatting.pg_format, -- WORKS BUT NO LSP ELSE BREAKS
				----------------                              ----------------

				-------------------        MARKDOWN       ------------------------
				-- formatting: PRETTIER FORMATTER
				-- null_ls.builtins.diagnostics.markdownlint, -- BREAKS MARKDOWN
				----------------                              ----------------

				-------------------        TOML       ------------------------
				-- formatting: PRETTIER FORMATTER
				--  diagnostics -- ***WE USE TAPLO***
				----------------                              ----------------

				-------------------        PRETTIER FORMATTER       ------------------------
				null_ls.builtins.formatting.prettierd.with({
					filetypes = {
						"javascript",
						"javascriptreact",
						"typescript",
						"typescriptreact",
						"vue",
						"css",
						"scss",
						"less",
						"html",
						"json",
						"jsonc",
						"yaml",
						"markdown",
						"markdown.mdx",
						"graphql",
						"handlebars",
					},
					extra_filetypes = { "toml", "svelte" },
				}),
				----------------                              ----------------
			},
		})

		vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, {})
	end,
}

-- diagnostic == linting
-- formatting == format
