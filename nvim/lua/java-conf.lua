function get_spring_boot_runner(profile, debug)
	local debug_param = ""
	if debug then
		debug_param =
			' -Dspring-boot.run.jvmArguments="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=5005" '
	end

	local profile_param = ""
	if profile then
		profile_param = " -Dspring-boot.run.profiles=" .. profile .. " "
	end

	return "mvn spring-boot:run " .. profile_param .. debug_param
end

function run_spring_boot(debug)
	vim.cmd("term " .. get_spring_boot_runner("local", debug))
end

vim.keymap.set("n", "<F9>", function()
	run_spring_boot()
end)
vim.keymap.set("n", "<F10>", function()
	run_spring_boot(true)
end)

function attach_to_debug()
	local dap = require("dap")
	dap.configurations.java = {
		{
			type = "java",
			request = "attach",
			name = "Attach to the process",
			hostName = "localhost",
			port = "5005",
		},
	}
	dap.continue()
end

function get_test_runner(test_name, debug)
	if debug then
		return 'mvn test -Dmaven.surefire.debug -Dtest="' .. test_name .. '"'
	end
	return 'mvn test -Dtest="' .. test_name .. '"'
end

function run_java_test_method(debug)
	local utils = require("utils")
	local method_name = utils.get_current_full_method_name("\\#")
	vim.cmd("term " .. get_test_runner(method_name, debug))
end

function run_java_test_class(debug)
	local utils = require("utils")
	local class_name = utils.get_current_full_class_name()
	vim.cmd("term " .. get_test_runner(class_name, debug))
end

--  attach remotely
vim.keymap.set("n", "<leader>da", ":lua attach_to_debug()<CR>")
-- vim.keymap.set("n", "<F5>", ':lua require"dap".continue()<CR>')
-- vim.keymap.set("n", "<F6>", function()
--   require("dap").continue()
-- end)

-- setup debug
vim.keymap.set("n", "<leader>b", ':lua require"dap".toggle_breakpoint()<CR>')
vim.keymap.set("n", "<leader>B", ':lua require"dap".set_breakpoint(vim.fn.input("Condition: "))<CR>')
vim.keymap.set("n", "<leader>bl", ':lua require"dap".set_breakpoint(nil, nil, vim.fn.input("Log: "))<CR>')
vim.keymap.set("n", "<leader>dr", ':lua require"dap".repl.open()<CR>')
vim.keymap.set("n", "<leader>rm", function()
	run_java_test_method()
end)
vim.keymap.set("n", "<leader>rM", function()
	run_java_test_method(true)
end)
vim.keymap.set("n", "<leader>rc", function()
	run_java_test_class()
end)
vim.keymap.set("n", "<leader>rC", function()
	run_java_test_class(true)
end)

-- view informations in debug
function show_dap_centered_scopes()
	local widgets = require("dap.ui.widgets")
	widgets.centered_float(widgets.scopes)
end

vim.keymap.set("n", "<leader>gs", ":lua show_dap_centered_scopes()<CR>")

require("jdtls").test_class()
require("jdtls").test_nearest_method()
vim.keymap.set("n", "<leader>dZ", function()
	require("jdtls").test_class()
end, { silent = true })
vim.keymap.set("n", "<leader>dn", function()
	require("jdtls").test_nearest_method()
end, { silent = true })



-- First, ensure your custom command is defined
vim.api.nvim_create_user_command(
  'RunDev',
  function()
    vim.api.nvim_command('split term://npm run dev')
  end,
  {desc = 'Run npm run dev in a split terminal'}
)

