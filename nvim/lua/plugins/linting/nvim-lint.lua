-- path: nvim/lua/plugins/linting/nvim-lint.lua
---@diagnostic disable: undefined-global

-- path: nvim/lua/plugins/linting/nvim-lint.lua
---@diagnostic disable: undefined-global
return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPost", "BufNewFile" },

	config = function()
		local lint = require("lint")

		-- ========= helpers (no ctx assumptions, super safe) =========
		local function buf_or_cwd(ctx)
			if ctx and ctx.filename and ctx.filename ~= "" then
				return ctx.filename
			end
			local name = vim.api.nvim_buf_get_name(0)
			return (name ~= "" and name) or vim.loop.cwd()
		end

		local function project_root(ctx)
			local start = buf_or_cwd(ctx)
			return vim.fs.root(start, { "package.json", "node_modules", ".git" })
				or (start ~= "" and vim.fs.dirname(start))
				or vim.loop.cwd()
		end

		local function exists(p)
			return type(p) == "string" and p ~= "" and vim.loop.fs_stat(p) ~= nil
		end

		local function prefer_local(exe, root)
			local local_path = (root or vim.loop.cwd()) .. "/node_modules/.bin/" .. exe
			if vim.fn.executable(local_path) == 1 then
				return local_path
			end
			local global = vim.fn.exepath(exe)
			return (global ~= "" and global) or nil
		end

		local function any_file(root, files)
			for _, f in ipairs(files) do
				if exists(root .. "/" .. f) then
					return true
				end
			end
			return false
		end
		-- ============================================================

		-- ----------- tighten built-ins & prefer local bins ----------
		-- ESLint (daemon) – only if project has config
		if lint.linters.eslint_d then
			lint.linters.eslint_d.cmd = function(ctx)
				return prefer_local("eslint_d", project_root(ctx))
			end
			lint.linters.eslint_d.condition = function(ctx)
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
			end
		end

		-- Stylelint – only if project has config
		if lint.linters.stylelint then
			lint.linters.stylelint.cmd = function(ctx)
				return prefer_local("stylelint", project_root(ctx))
			end
			lint.linters.stylelint.condition = function(ctx)
				local root = project_root(ctx)
				return any_file(root, {
					".stylelintrc",
					".stylelintrc.json",
					".stylelintrc.yaml",
					".stylelintrc.yml",
					".stylelintrc.js",
					"stylelint.config.js",
					"stylelint.config.cjs",
					"package.json",
				})
			end
		end

		-- Markdownlint – prefer local CLI, otherwise global
		if lint.linters.markdownlint then
			lint.linters.markdownlint.cmd = function(ctx)
				-- npm i -D markdownlint-cli  (binary: markdownlint)
				return prefer_local("markdownlint", project_root(ctx)) or "markdownlint"
			end
			-- keep builtin args/parser (supports --stdin)
		end

		-- Vale (prose linter) – only if repo has config
		if lint.linters.vale then
			lint.linters.vale.condition = function(ctx)
				local root = project_root(ctx)
				return any_file(root, { ".vale.ini", "_vale.ini", "vale.ini" })
			end
		end

		-- Ruff – just use whatever is on PATH (pipx or venv)
		-- (Built-in config is already good.)
		-- Yamllint – pipx, built-in config is fine.
		-- Shellcheck – Homebrew; built-in config is fine.
		-- Fish – built-in uses `fish -n %filepath` (no stdin); perfect.
		-- Luacheck – optional; only if installed.

		-- ----------------- filetype → linters map -------------------
		lint.linters_by_ft = {
			-- Python
			python = { "ruff" },

			-- JS/TS (eslint_d if configured; falls back to nothing if not found)
			javascript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescript = { "eslint_d" },
			typescriptreact = { "eslint_d" },

			-- CSS family
			css = { "stylelint" },
			scss = { "stylelint" },
			less = { "stylelint" },

			-- Markdown / prose
			-- markdown = { "markdownlint" }, -- OFF

			-- YAML
			yaml = { "yamllint" },

			-- Shells
			sh = { "shellcheck" },
			bash = { "shellcheck" },
			zsh = { "shellcheck" }, -- shellcheck can still catch lots here
			fish = { "fish" },

			-- Lua (optional)
			-- lua = { "luacheck" }, -- requires luacheck installed -- OFF
			-- Dockerfile = { "hadolint" },   -- enable if you install hadolint
		}
		-- ------------------------------------------------------------

		-- --------------- buttery-smooth autolinting -----------------
		local enabled = true
		local aug = vim.api.nvim_create_augroup("LintAuto", { clear = true })

		-- Low-noise: on write, on leaving insert, and when opening a buffer
		vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave", "BufReadPost" }, {
			group = aug,
			callback = function(args)
				if not enabled then
					return
				end
				-- try_lint(): runs only configured linters for the buffer’s ft
				require("lint").try_lint(nil, { bufnr = args.buf })
			end,
		})

		-- Handy commands
		vim.api.nvim_create_user_command("LintNow", function()
			require("lint").try_lint()
		end, {})

		vim.api.nvim_create_user_command("LintToggle", function()
			enabled = not enabled
			vim.notify(("Linting %s"):format(enabled and "ENABLED" or "DISABLED"))
		end, {})

		vim.api.nvim_create_user_command("LintInfo", function()
			local ft = vim.bo.filetype
			local configured = lint.linters_by_ft[ft] or {}
			local active = {}
			for _, name in ipairs(configured) do
				local l = lint.linters[name]
				if
					l
					and (
						not l.condition
						or l.condition({ filename = vim.api.nvim_buf_get_name(0), cwd = vim.loop.cwd() })
					)
				then
					table.insert(active, name)
				end
			end
			vim.notify(
				("Filetype: %s\nConfigured: %s\nActive now: %s"):format(
					ft,
					table.concat(configured, ", "),
					(#active > 0 and table.concat(active, ", ") or "none")
				),
				vim.log.levels.INFO,
				{ title = "nvim-lint" }
			)
		end, {})
		-- ------------------------------------------------------------
	end,
}
