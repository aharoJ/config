-- vim.opt_local.shiftwidth = 4
-- vim.opt_local.tabstop = 4
-- vim.opt_local.softtabstop = 4
-- vim.opt_local.ts = 4
-- vim.opt_local.expandtab = true

-------------------    JDTLS    ------------------------
local status, jdtls = pcall(require, "jdtls")
if not status then
  return
end
----------------                              ----------------

-------------------    CAPABILITIES    ------------------------
local function capabilities()
  local status_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if status_ok then
    return cmp_nvim_lsp.default_capabilities()
  end

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  }

  return capabilities
end
----------------                              ----------------

-------------------    DIRECTORY    ------------------------
local function directory_exists(path)
  local f, err = io.popen("cd " .. path)
  if not f then
    print("Error opening pipe: " .. err)
    return false
  end

  local ff = f:read("*all")
  if not ff then
    print("Error reading from pipe")
    f:close()
    return false
  end

  f:close()
  return ff:find("cannot access") == nil
end

local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }
local root_dir = require("jdtls.setup").find_root(root_markers)

local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_dir = vim.fn.stdpath("data") .. "/site/java/workspace-root/" .. project_name
if not directory_exists(workspace_dir) then
  os.execute("mkdir -p " .. workspace_dir)
end
----------------                              ----------------

-------------------    BUNDLES    ------------------------
local bundles = { -- https://github.com/mfussenegger/nvim-jdtls?tab=readme-ov-file#nvim-dap-configuration
  vim.fn.glob(
    "/Users/aharo/.local/share/nvim/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
    1
  ),
}
vim.list_extend(
  bundles,
  vim.split(vim.fn.glob("/Users/aharo/.local/share/nvim/mason/packages/java-test/extension/server/*.jar", 1), "\n")
)
----------------                              ----------------

local config = {
  cmd = {
    "java",
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
    "-Xms1g",
    "--add-modules=ALL-SYSTEM",
    "--add-opens",
    "java.base/java.util=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.lang=ALL-UNNAMED",
    "-javaagent:/Users/aharo/.local/share/nvim/java-stuff/lombok.jar",
    "-jar",
    vim.fn.glob("/Users/aharo/.local/share/nvim/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
    "-configuration",
    vim.fn.glob("/Users/aharo/.local/share/nvim/mason/packages/jdtls/config_mac"),
    "-data",
    workspace_dir,
  },
  capabilities = capabilities(),
  root_dir = root_dir,
  settings = {
    java = {
      format = {
        enabled = true,
        settings = {
          url = "/Users/aharo/.local/share/nvim/java-stuff/intellij-java-google-style.xml",
          profile = "GoogleStyle",
        },
      },
      signatureHelp = { enabled = true }, -- https://github.com/mfussenegger/nvim-jdtls/discussions/124
      useBlocks = true,                -- ^
      generateComments = true,         -- ^
    },
  },
  init_options = {
    bundles = bundles,
  },
}

config["on_attach"] = function(client, bufnr)
  local _, _ = pcall(vim.lsp.codelens.refresh)
  require("jdtls.dap").setup_dap_main_class_configs()
  jdtls.setup_dap({ hotcodereplace = "auto" })
  require("java-conf").on_attach(client, bufnr)
end

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  pattern = { "*.java" },
  callback = function()
    local _, _ = pcall(vim.lsp.codelens.refresh)
  end,
})

jdtls.start_or_attach(config)

vim.cmd(
  [[command! -buffer -nargs=? -complete=custom,v:lua.require'jdtls'._complete_set_runtime JdtSetRuntime lua require('jdtls').set_runtime(<f-args>)]]
)
