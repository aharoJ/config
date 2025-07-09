-- path: nvim/lua/settings/diagnostic.lua
-- ============================================================================
-- diagnostic
-- ============================================================================
-- Use this instead in your diagnostic config:
vim.diagnostic.config({
    virtual_text = {
        source = "always",
        prefix = "●",
        spacing = 4,
    },
    signs = {
        text = {
            -- [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN]  = "",
            [vim.diagnostic.severity.INFO]  = " ",
            [vim.diagnostic.severity.HINT]  = "",
        }
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
        source = "always",
        border = "rounded",
        header = "",
        prefix = function(diagnostic)
            local icons = {
                [vim.diagnostic.severity.ERROR] = " ",
                [vim.diagnostic.severity.WARN]  = " ",
                [vim.diagnostic.severity.INFO]  = " ",
                [vim.diagnostic.severity.HINT]  = "  ",
            }
            return icons[diagnostic.severity]
        end,
    },
})


-- Define diagnostic signs
vim.fn.sign_define("DiagnosticSignError", { text = "", texthl = "DiagnosticSignError" })
vim.fn.sign_define("DiagnosticSignWarn", { text = " ", texthl = "DiagnosticSignWarn" })
vim.fn.sign_define("DiagnosticSignInfo", { text = " ", texthl = "DiagnosticSignInfo" })
vim.fn.sign_define("DiagnosticSignHint", { text = " ", texthl = "DiagnosticSignHint" })

-- 
-- 
-- 
-- 
