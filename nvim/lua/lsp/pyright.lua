-- path: nvim/lua/plugins/lsp/pyright.lua

local M = {}

function M.setup(ctx)
    local overrides = {
        reportUnusedVariable    = "none",
        reportUnusedImport      = "none",
        reportUnusedFunction    = "none",
        reportDuplicateImport   = "none",
        reportRedeclaration     = "none",
        reportShadowedImports   = "none",
        reportUndefinedVariable = "none", -- Ruff F821
    }

    vim.lsp.config("pyright", {
        on_attach = ctx.on_attach,
        capabilities = ctx.capabilities,
        settings = {
            python = {
                analysis = {
                    typeCheckingMode = "basic",
                    autoImportCompletions = true,
                    diagnosticMode = "workspace",
                    useLibraryCodeForTypes = true,
                    diagnosticSeverityOverrides = overrides,
                },
            },
        },
    })
end

return M
