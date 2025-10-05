local M = {}

function M.setup(ctx)
    -- Binary is "ruff" (it runs the LSP via `ruff server`)
    vim.lsp.config("ruff", {
        on_attach = function(client, bufnr)
            -- Defer hover to Pyright (nicer type hovers)
            client.server_capabilities.hoverProvider = false
            if ctx and ctx.on_attach then ctx.on_attach(client, bufnr) end
        end,
        capabilities = ctx.capabilities,
        init_options = {
            settings = {
                -- Pass extra CLI args to ruff here if you like
                args = {},

                -- Fine-grained code action toggles (Ruff LSP settings)
                codeAction = {
                    fixViolation = { enable = true },
                    organizeImports = { enable = true },
                },
                -- You can also pin a config file path or inline config:
                -- configuration = "/absolute/path/to/ruff.toml",
            },
        },
    })
end

return M
