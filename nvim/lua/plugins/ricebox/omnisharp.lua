-- lua/plugins/ricebox/omnisharp.lua
local M = {}

function M.setup(capabilities)
  local lspconfig = require("lspconfig")
  local omnisharp_path = vim.fn.stdpath("data") .. "/mason/packages/omnisharp/libexec/OmniSharp.dll"

  local omnisharp_extended = require("omnisharp_extended")

  lspconfig.omnisharp.setup({
    capabilities = capabilities,
    cmd = { "dotnet", omnisharp_path },
    enable_editorconfig_support = true,
    enable_roslyn_analyzers = true,
    organize_imports_on_format = true,
    enable_import_completion = true,
    handlers = {
      ["textDocument/definition"] = omnisharp_extended.definition_handler,
      ["textDocument/references"] = omnisharp_extended.references_handler,
      ["textDocument/implementation"] = omnisharp_extended.implementation_handler,
    },
    settings = {
      FormattingOptions = {
        EnableEditorConfigSupport = true,
        OrganizeImports = true,
      },
      MsBuild = {
        LoadProjectsOnDemand = true,
      },
      RoslynExtensionsOptions = {
        EnableAnalyzersSupport = true,
        EnableImportCompletion = true,
        AnalyzeOpenDocumentsOnly = true,
      },
      Sdk = {
        IncludePrereleases = true,
      },
    },
  })
end

return M

-- src:
-- -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#omnisharp
