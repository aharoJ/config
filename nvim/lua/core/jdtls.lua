-- path: ~/.config/nvim/lua/core/jdtls.lua

local M = {}

-- ── tiny utils ────────────────────────────────────────────────────────────────
local uv, fn = (vim.uv or vim.loop), vim.fn
local function is_dir(p)
	return p and #p > 0 and (uv.fs_stat(p) or {}).type == "directory"
end
local function is_file(p)
	return p and #p > 0 and (uv.fs_stat(p) or {}).type == "file"
end
local function first_glob(pat)
	local g = fn.glob(pat)
	if g == "" then
		return nil
	end
	return vim.split(g, "\n", { trimempty = true })[1]
end
local function all_glob(pat)
	local g = fn.glob(pat)
	if g == "" then
		return {}
	end
	return vim.split(g, "\n", { trimempty = true })
end
local function os_config_dir()
	if fn.has("mac") == 1 then
		return "config_mac"
	end
	if fn.has("unix") == 1 then
		return "config_linux"
	end
	return "config_win"
end

local function project_root()
	local markers = { "mvnw", "pom.xml", "gradlew", "build.gradle", "settings.gradle", "settings.gradle.kts", ".git" }
	local ok, setup = pcall(require, "jdtls.setup")
	if ok then
		return setup.find_root(markers) or uv.cwd()
	end
	return uv.cwd()
end
local function project_name(root)
	return vim.fs.basename(root)
end

-- ── mason / env paths ─────────────────────────────────────────────────────────
local function mason_base()
	return fn.stdpath("data") .. "/mason"
end
local function jdtls_base_dir()
	local env = vim.env.JDTLS_HOME
	if env and is_dir(env) then
		return env
	end
	local mason = mason_base() .. "/packages/jdtls"
	if is_dir(mason) then
		return mason
	end
	return nil
end
local function lombok_jar()
	local env = vim.env.LOMBOK_JAR
	if env and is_file(env) then
		return env
	end
	local nightly = mason_base() .. "/packages/lombok-nightly/lombok.jar"
	if is_file(nightly) then
		return nightly
	end
	local stable = mason_base() .. "/packages/lombok/lombok.jar"
	if is_file(stable) then
		return stable
	end
	local local_drop = fn.stdpath("data") .. "/java/lombok.jar"
	if is_file(local_drop) then
		return local_drop
	end
	return nil
end
local function debug_bundle()
	return first_glob(
		mason_base() .. "/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"
	)
end
local function test_bundles()
	return all_glob(mason_base() .. "/packages/java-test/extension/server/*.jar")
end
local function spring_bundles()
	-- optional: export SPRING_TOOLS_JAR_DIR=/path/to/*.jar for extra goodies
	local dir = vim.env.SPRING_TOOLS_JAR_DIR
	if not (dir and is_dir(dir)) then
		return {}
	end
	return all_glob(dir .. "/*.jar")
end

-- ── runtimes (Java 17/21/23/24…) ─────────────────────────────────────────────
local function jdk_runtime(name, envvar, fallback_path, default_)
	local p = vim.env[envvar] or fallback_path
	if p and is_dir(p) then
		return { name = name, path = p, default = default_ or false }
	end
end
local function configured_runtimes()
	-- JDTLS itself prefers Java 21+; projects may target 17/21/23/24…
	local r, home = {}, vim.env.JAVA_HOME
	local add = function(rt)
		if rt then
			table.insert(r, rt)
		end
	end
	add(jdk_runtime("JavaSE-17", "JAVA_17_HOME", nil, false))
	add(jdk_runtime("JavaSE-21", "JAVA_21_HOME", home, true)) -- make 21 default if nothing else
	add(jdk_runtime("JavaSE-23", "JAVA_23_HOME", nil, false))
	add(jdk_runtime("JavaSE-24", "JAVA_24_HOME", nil, false))
	return r
end

-- ── capabilities / on_attach ──────────────────────────────────────────────────
local function lsp_capabilities()
	local caps = vim.lsp.protocol.make_client_capabilities()
	local ok, cmp = pcall(require, "cmp_nvim_lsp")
	if ok then
		caps = cmp.default_capabilities(caps)
	end
	return caps
end

local function on_attach(_, bufnr)
	local map = function(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
	end
	local jdtls = require("jdtls")

	-- ── enforce 2-space indentation for *Java buffers only* ────────────────────
	vim.bo[bufnr].expandtab = true -- use spaces, not tabs
	vim.bo[bufnr].shiftwidth = 2 -- >>, <<, autoindent width
	vim.bo[bufnr].tabstop = 2 -- visual width of <Tab>
	vim.bo[bufnr].softtabstop = 2 -- <BS>/<Tab> feel like 2 spaces
	vim.bo[bufnr].copyindent = true -- copy indent structure on new lines

	-- lean java power actions (you likely have global LSP maps already)
	map("n", "<leader>jo", jdtls.organize_imports, "Java: Organize Imports")
	map("v", "<leader>jv", jdtls.extract_variable, "Java: Extract Variable")
	map("v", "<leader>jm", jdtls.extract_method, "Java: Extract Method")
	map("n", "<leader>js", jdtls.super_implementation, "Java: Super Implementation")
	map("n", "<leader>jj", jdtls.javap, "Java: javap current class")
	map("n", "<leader>jh", jdtls.jshell, "Java: JShell")

	-- inside on_attach(_, bufnr)
	map("n", "<leader>ca", function()
		vim.lsp.buf.code_action()
	end, "LSP: Code action")
	map("v", "<leader>ca", function()
		vim.lsp.buf.code_action()
	end, "LSP: Code action (range)")

	-- DAP wiring (only if nvim-dap present)
	if pcall(require, "dap") then
		pcall(jdtls.setup_dap, { hotcodereplace = "auto" })
		-- ⬇️ correct call (no .dap)
		pcall(function()
			if jdtls.setup_dap_main_class_configs then
				jdtls.setup_dap_main_class_configs()
			end
		end)
	end

	-- keep main-class configs fresh after saves
	vim.api.nvim_create_autocmd("BufWritePost", {
		buffer = bufnr,
		group = vim.api.nvim_create_augroup("JdtlsMainClassRefresh", { clear = false }),
		callback = function()
			pcall(function()
				if jdtls.setup_dap_main_class_configs then
					jdtls.setup_dap_main_class_configs()
				end
			end)
		end,
	})
end

-- ── command builder ───────────────────────────────────────────────────────────
local function build_cmd(jdtls_home, workspace_dir)
	local launcher = first_glob(jdtls_home .. "/plugins/org.eclipse.equinox.launcher_*.jar")
	local config = jdtls_home .. "/" .. os_config_dir()
	local java_bin = vim.env.JDTLS_JAVA or "java"
	local xmx = vim.env.JDTLS_XMX or "2G"

	local cmd = {
		java_bin,
		"-Declipse.application=org.eclipse.jdt.ls.core.id1",
		"-Dosgi.bundles.defaultStartLevel=4",
		"-Declipse.product=org.eclipse.jdt.ls.core.product",
		"-Dlog.protocol=true",
		"-Dlog.level=ALL",
		"-Dfile.encoding=UTF-8",
		"-Xms512m",
		"-Xmx" .. xmx,
		"--add-modules=ALL-SYSTEM",
		"--add-opens",
		"java.base/java.util=ALL-UNNAMED",
		"--add-opens",
		"java.base/java.lang=ALL-UNNAMED",
		"-jar",
		launcher,
		"-configuration",
		config,
		"-data",
		workspace_dir,
	}
	local lombok = lombok_jar()
	if lombok then
		table.insert(cmd, 8, "-javaagent:" .. lombok)
	end -- before -jar is safe
	return cmd
end

local function extended_capabilities()
	local ec = require("jdtls").extendedClientCapabilities
	ec.resolveAdditionalTextEditsSupport = true
	ec.progressReportProvider = true
	ec.classFileContentsSupport = true
	return ec
end

local function bundles_all()
	local list = {}
	local dbg = debug_bundle()
	if dbg then
		table.insert(list, dbg)
	end
	local tests = test_bundles()
	if #tests > 0 then
		vim.list_extend(list, tests)
	end
	local spring = spring_bundles()
	if #spring > 0 then
		vim.list_extend(list, spring)
	end
	return list
end

local function settings_java()
	return {
		java = {
			eclipse = { downloadSources = true },
			maven = { downloadSources = true, updateSnapshots = true },
			signatureHelp = { enabled = true },
			references = { includeDecompiledSources = true },
			contentProvider = { preferred = "fernflower" },
			completion = {
				favoriteStaticMembers = {
					"org.assertj.core.api.Assertions.*",
					"org.mockito.Mockito.*",
					"org.hamcrest.MatcherAssert.assertThat",
					"org.hamcrest.Matchers.*",
					"org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
					"org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
					"java.util.Objects.requireNonNull",
					"java.util.Optional.*",
				},
				filteredTypes = { "com.sun.*", "sun.*", "java.awt.*", "javax.swing.*" },
			},
			sources = {
				organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
			},
			-- keep formatter off unless you point to a team XML profile
			format = {
				enabled = true,
				-- settings = { url = "/abs/path/to/your-formatter.xml", profile = "YourProfile" },
			},
			configuration = {
				updateBuildConfiguration = "interactive", -- "automatic" if you prefer
				runtimes = configured_runtimes(),
			},
			inlayHints = { parameterNames = { enabled = "literals" } },
			implementationsCodeLens = { enabled = true },
			referencesCodeLens = { enabled = true },
		},
	}
end

-- ── start/attach ──────────────────────────────────────────────────────────────
function M.start_or_attach()
	local root = project_root()
	if not root or root == "" then
		vim.notify("[jdtls] no project root found", vim.log.levels.WARN)
		return
	end

	local jdtls_home = jdtls_base_dir()
	if not jdtls_home then
		vim.notify("[jdtls] eclipse.jdt.ls not found. Install via :Mason or set $JDTLS_HOME", vim.log.levels.ERROR)
		return
	end

	local ws = fn.stdpath("data") .. "/jdtls/workspace/" .. project_name(root)
	fn.mkdir(ws, "p")

	local jdtls = require("jdtls")
	local config = {
		cmd = build_cmd(jdtls_home, ws),
		root_dir = root,
		settings = settings_java(),
		init_options = {
			bundles = bundles_all(),
			extendedClientCapabilities = extended_capabilities(),
		},
		capabilities = lsp_capabilities(),
		on_attach = on_attach,
		flags = { allow_incremental_sync = true, debounce_text_changes = 80 },
	}

	jdtls.start_or_attach(config)
end

function M.setup_autocmd()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "java",
		group = vim.api.nvim_create_augroup("JdtlsAutoStart", { clear = true }),
		callback = function()
			M.start_or_attach()
		end,
	})
end

return M
