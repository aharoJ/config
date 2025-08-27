-- path: nvim/ftplugin/java.lua

local jdtls_ok, jdtls = pcall(require, "jdtls")
if not jdtls_ok then return end

-- Find project root
local root_dir = require("jdtls.setup").find_root({
  ".git", "mvnw", "gradlew", "pom.xml", "build.gradle"
})
if not root_dir then return end

local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
local workspace_dir = vim.fn.stdpath("data") .. "/site/java/workspace-root/" .. project_name

-- Ensure workspace directory exists
if vim.fn.isdirectory(workspace_dir) == 0 then
  vim.fn.mkdir(workspace_dir, "p")
end

-- Get capabilities
local capabilities
local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if cmp_ok then
  capabilities = cmp_nvim_lsp.default_capabilities()
else
  capabilities = vim.lsp.protocol.make_client_capabilities()
end
-- Disable snippet completion items from JDTLS only
capabilities.textDocument.completion.completionItem.snippetSupport = true
----------------------------------------------------------------------

-- Debug/test bundles
local bundles = {
  vim.fn.glob(
    vim.fn.stdpath("data") .. "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
    1
  ),
}
vim.list_extend(
  bundles,
  vim.split(vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/java-test/extension/server/*.jar", 1), "\n")
)

local config = {
  cmd = {
    vim.fn.stdpath("data") .. "/mason/bin/jdtls",
    "--jvm-arg=-javaagent:" .. vim.fn.stdpath("data") .. "/java-stuff/lombok.jar",
    "--jvm-arg=-Xmx4G",
    "--jvm-arg=--add-modules=ALL-SYSTEM",
    "--jvm-arg=--add-opens=java.base/java.util=ALL-UNNAMED",
    "--jvm-arg=--add-opens=java.base/java.lang=ALL-UNNAMED",
    "-data", workspace_dir
  },
  root_dir = root_dir,
  capabilities = capabilities,
  init_options = {
    bundles = bundles,
  },
  settings = {
    java = {
      format = {
        enabled = true,
        settings = {
          url = vim.fn.stdpath("data") .. "/java-stuff/intellij-java-google-style.xml",
          profile = "GoogleStyle",
        },
      },
      signatureHelp = { enabled = true },
    },
  },
on_attach = function(client, bufnr)
    pcall(vim.lsp.codelens.refresh)
    -- Set buffer-local keymap for formatting with JDTLS
    vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { buffer = bufnr, desc = "Format with JDTLS" })
  end,
}

jdtls.start_or_attach(config)

-- Refresh code lenses on save
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  pattern = { "*.java" },
  callback = function()
    pcall(vim.lsp.codelens.refresh)
  end,
})
