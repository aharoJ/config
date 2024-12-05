-- ftplugin/java.lua
local home = os.getenv("HOME")
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_folder = home .. "/.cache/jdtls/workspace" .. project_name

local capabilities = require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities())
local on_attach = function(client, bufnr)
	require("jdtls.dap").setup_dap_main_class_configs()
	require("debugging").map_java_keys(bufnr)
	require("lsp_signature").on_attach({
		bind = true,
		doc_lines = 2,
		floating_window = true,
		hint_enable = true,
		handler_opts = {
			border = "single",
		},
		zindex = 50,
		padding = "",
		transpancy = 20,
		max_height = 12,
	}, bufnr)
	require("jdtls").setup_dap({ hotcodereplace = "auto" })
end

local config = {
	cmd = {
		"java",
		"-Declipse.application=org.eclipse.jdt.ls.core.id1",
		"-Dosgi.bundles.defaultStartLevel=4",
		"-Declipse.product=org.eclipse.jdt.ls.core.product",
		"-Dlog.level=ALL",
		"-Xmx1G",
		"-jar",
		home
			.. "/.local/share/nvim/java-stuff/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/plugins/org.eclipse.equinox.launcher_1.6.800.v20240304-1850.jar",
		"-configuration",
		home .. "/.local/share/nvim/java-stuff/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/config_mac",
		"-data",
		workspace_folder,
	},
	on_attach = on_attach,
	root_dir = require("jdtls.setup").find_root({ ".git", "mvnw", "gradlew" }),
	capabilities = capabilities,
	settings = {
		-- settings configuration
	},
	flags = {
		allow_incremental_sync = true,
	},
	init_options = {
		bundles = {
			vim.fn.glob(
				"/Users/aharo/.local/share/nvim/java-stuff/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-0.52.0.jar",
				1
			),
		},
	},
}

local dap = require("dap")

-- Setup DAP templates for various programming languages
dap.adapters.java = function(callback, _)
	callback({
		type = "executable",
		command = "java",
		args = {
			"-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005",
			"-jar",
			vim.fn.glob(
				"/Users/aharo/.local/share/nvim/java-stuff/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-0.52.0.jar"
			),
		},
	})
end

dap.configurations.java = {
	{
		type = "java",
		request = "attach",
		name = "Debug (Attach) - Remote",
		hostName = "127.0.0.1",
		port = 5005,
	},
}

require("jdtls").start_or_attach(config)

-------------------    RUNS PROJECT ------------------------
vim.cmd([[
function! CompileAndRunJavaPackage()
    let l:current_file = expand('%')
    let l:package_directory = expand('%:p:h')
    let l:parent_directory = fnamemodify(l:package_directory, ':h')
    " Compile all Java files in the current package directory
    let compile_command = '!javac ' . l:package_directory . '/*.java'
    execute compile_command
    " Determine the package name by extracting the relative path and replacing slashes with dots
    let l:package_name = substitute(l:package_directory, l:parent_directory.'/', '', '')
    let l:package_name = substitute(l:package_name, '/', '.', 'g')
    " Extract the class name from the current file name
    let l:class_name = fnamemodify(l:current_file, ':t:r')
    " Concatenate to form the fully qualified class name
    let l:full_class = l:package_name . '.' . l:class_name
    " Run the compiled class without opening a new buffer or window
    let run_command = '!java -cp ' . l:parent_directory . ' ' . l:full_class
    execute run_command
endfunction
]])

vim.api.nvim_set_keymap("n", "<Space>rp", ":call CompileAndRunJavaPackage()<CR>", { noremap = true, silent = true })
----------------                              ----------------

-------------------    RUNS FILE    ------------------------
vim.api.nvim_set_keymap(
  "n",
  "<Space>rf",
  ':w!<CR>:!javac % && echo "" && echo "OUTPUT:" && java %<CR>',
  { noremap = true, silent = true })
----------------                              ----------------
