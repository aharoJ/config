-- path: nvim/lua/plugins/formatting/conform.lua
---@diagnostic disable: undefined-global
return {
	"stevearc/conform.nvim",
	cmd = { "ConformInfo" },
	keys = {
		{ "<leader>cF", function() require("conform").format({ async = true, lsp_format = "fallback" }) end, desc = "Format buffer", },
        
        {
            "<leader>f",
            function()
                require("conform").format({ async = true, lsp_format = "fallback" }, function(err)
                    if not err then
                        local mode = vim.api.nvim_get_mode().mode
                        if mode:lower():find("^v") then
                            vim.api.nvim_feedkeys(
                                vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
                                "n",
                                true
                            )
                        end
                    end
                end)
            end,
            mode = "v",
            desc = "Format selection (Conform)",
        },














	},

	opts = function()
		-- ---------- helpers that never assume ctx ----------
		local function buf_or_cwd(ctx)
			-- best-effort path for root detection
			if ctx and ctx.filename and ctx.filename ~= "" then
				return ctx.filename
			end
			local name = vim.api.nvim_buf_get_name(0)
			return name ~= "" and name or vim.loop.cwd()
		end

		local function project_root(ctx)
			local start = buf_or_cwd(ctx)
			return vim.fs.root(start, { "package.json", "node_modules", ".git" })
				or (start ~= "" and vim.fs.dirname(start))
				or vim.loop.cwd()
		end

		local function local_bin(bin, root)
			local p = (root or vim.loop.cwd()) .. "/node_modules/.bin/" .. bin
			return (vim.fn.executable(p) == 1) and p or nil
		end

		local function resolve_cmd(bin, ctx)
			-- prefer local node_modules/.bin, else absolute global, else nil
			local root = project_root(ctx)
			local local_path = local_bin(bin, root)
			if local_path then
				return local_path
			end
			local global_path = vim.fn.exepath(bin)
			return (global_path ~= "" and global_path) or nil
		end

		local function exists(path)
			return type(path) == "string" and path ~= "" and vim.loop.fs_stat(path) ~= nil
		end

		local function any_file(root, names)
			for _, n in ipairs(names) do
				if exists(root .. "/" .. n) then
					return true
				end
			end
			return false
		end
		-- ---------------------------------------------------

		local conform = require("conform")

		-- prettierd (daemon) — fastest
		conform.formatters.prettierd = {
			command = function(_, ctx)
				return resolve_cmd("prettierd", ctx) -- may be nil if not installed
			end,
			cwd = function(_, ctx)
				return project_root(ctx)
			end,
			stdin = true,
		}

		-- prettier fallback, tailwind-aware if plugin is present in the project
		conform.formatters.prettier_tailwind = {
			command = function(_, ctx)
				return resolve_cmd("prettier", ctx)
			end,
			args = function(_, ctx)
				local args = { "--stdin-filepath", "$FILENAME" }
				local root = project_root(ctx)
				local plugin_dir = root .. "/node_modules/prettier-plugin-tailwindcss"
				if exists(plugin_dir) then
					table.insert(args, "--plugin")
					-- pass absolute path so global prettier can load the local plugin
					table.insert(args, plugin_dir)
				end
				return args
			end,
			cwd = function(_, ctx)
				return project_root(ctx)
			end,
			stdin = true,
		}

		-- eslint_d quick-fix (optional pre-pass for JS/TS projects)
		conform.formatters.eslint_d = {
			command = function(_, ctx)
				return resolve_cmd("eslint_d", ctx)
			end,
			args = { "--fix-to-stdout", "--stdin", "--stdin-filename", "$FILENAME" },
			stdin = true,
			cwd = function(_, ctx)
				return project_root(ctx)
			end,
			condition = function(_, ctx)
				local root = project_root(ctx)
				return any_file(root, {
					"eslint.config.js",
					"eslint.config.mjs",
					"eslint.config.cjs",
					".eslintrc",
					".eslintrc.js",
					".eslintrc.cjs",
					".eslintrc.json",
					".eslintrc.yaml",
					".eslintrc.yml",
					"package.json",
				})
			end,
		}

		-- others (simple binaries)
		conform.formatters.yamlfmt = { command = "yamlfmt", stdin = true }
		conform.formatters.taplo = { command = "taplo", args = { "format", "-" }, stdin = true }
		conform.formatters.shfmt = { command = "shfmt", stdin = true }
		conform.formatters.fish_indent = { command = "fish_indent", stdin = true }
		conform.formatters.stylua = { command = "stylua", args = { "-" }, stdin = true }

		return {
			-- choose: true = fastest; false = run chains like eslint_d → prettierd
			stop_after_first = true,
			format_on_save = false,
			default_format_opts = { lsp_format = "fallback", timeout_ms = 2000 },
			notify_on_error = true,

			formatters_by_ft = {
				lua = { "stylua" },

				-- web stack
				javascript = { "eslint_d", "prettierd", "prettier_tailwind" },
				javascriptreact = { "eslint_d", "prettierd", "prettier_tailwind" },
				typescript = { "eslint_d", "prettierd", "prettier_tailwind" },
				typescriptreact = { "eslint_d", "prettierd", "prettier_tailwind" },
				json = { "prettierd", "prettier_tailwind" },
				jsonc = { "prettierd", "prettier_tailwind" },
				html = { "prettierd", "prettier_tailwind" },
				css = { "prettierd", "prettier_tailwind" },
				scss = { "prettierd", "prettier_tailwind" },
				less = { "prettierd", "prettier_tailwind" },

				-- markdown anywhere (not project-bound)
				markdown = { "prettierd", "prettier_tailwind" },
				mdx = { "prettierd", "prettier_tailwind" },

				-- infra / shells
				yaml = { "yamlfmt", "prettierd", "prettier_tailwind" },
				toml = { "taplo" },
				sh = { "shfmt" },
				fish = { "fish_indent" },
			},
		}
	end,

	init = function()
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}
