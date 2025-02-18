-- ~/.config/nvim/lua/java-conf.lua

local M = {}

local function setup_dap()
  local dap = require("dap")
  -- Remove or comment out the manual adapter configuration:
  --[[
  dap.adapters.java = {
    type = 'executable',
    command = 'java',
    args = {
      '-jar',
      vim.fn.glob("/Users/aharo/.local/share/nvim/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar")
    }
  }
  dap.configurations.java = {
    {
      type = 'java',
      request = 'attach',
      name = "Attach to Process",
      hostName = "localhost",
      port = "5005",
    },
  }
  ]]
end

local function get_spring_boot_runner(profile, debug)
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

local function run_spring_boot(debug)
  vim.cmd("term " .. get_spring_boot_runner("local", debug))
end

local function attach_to_debug()
  local dap = require("dap")
  dap.continue()
end

local function get_test_runner(test_name, debug)
  if debug then
    return 'mvn test -Dmaven.surefire.debug -Dtest="' .. test_name .. '"'
  end
  return 'mvn test -Dtest="' .. test_name .. '"'
end

local function run_java_test_method(debug)
  local utils = require("utils")
  local ok, method_name = pcall(utils.get_current_full_method_name, "\\#")
  if ok and method_name then
    vim.cmd("term " .. get_test_runner(method_name, debug))
  end
end

local function run_java_test_class(debug)
  local utils = require("utils")
  local ok, class_name = pcall(utils.get_current_full_class_name)
  if ok and class_name then
    vim.cmd("term " .. get_test_runner(class_name, debug))
  end
end

local function show_dap_centered_scopes()
  local widgets = require("dap.ui.widgets")
  widgets.centered_float(widgets.scopes)
end

function M.setup()
  setup_dap()

  -- Spring Boot mappings
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>ZZ", "<cmd>lua require('java-conf').run_spring_boot()<CR>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "<F10>", "<cmd>lua require('java-conf').run_spring_boot(true)<CR>", {})

  -- Debug mappings
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>da", "<cmd>lua require('java-conf').attach_to_debug()<CR>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>b", "<cmd>lua require('dap').toggle_breakpoint()<CR>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>B",
  "<cmd>lua require('dap').set_breakpoint(vim.fn.input('Condition: '))<CR>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>bl",
    "<cmd>lua require('dap').set_breakpoint(nil, nil, vim.fn.input('Log: '))<CR>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>dr", "<cmd>lua require('dap').repl.open()<CR>", {})

  -- Test mappings
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>rm", "<cmd>lua require('java-conf').run_java_test_method()<CR>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>rM", "<cmd>lua require('java-conf').run_java_test_method(true)<CR>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>rc", "<cmd>lua require('java-conf').run_java_test_class()<CR>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>rC", "<cmd>lua require('java-conf').run_java_test_class(true)<CR>", {})

  -- Scopes view mapping
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>gs", "<cmd>lua require('java-conf').show_dap_centered_scopes()<CR>", {})

  -- (Optional) You may include additional mappings as needed.
end

-- Export functions
M.run_spring_boot = run_spring_boot
M.attach_to_debug = attach_to_debug
M.run_java_test_method = run_java_test_method
M.run_java_test_class = run_java_test_class
M.show_dap_centered_scopes = show_dap_centered_scopes

return M
