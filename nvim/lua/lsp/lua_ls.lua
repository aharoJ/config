-- path: lua/lsp/lua_ls.lua
local M = {}

function M.setup(ctx)
    -- resolve binary if PATH is odd
    local cmd = vim.fn.exepath("lua-language-server")
    if cmd == "" then
        if vim.fn.filereadable("/opt/homebrew/bin/lua-language-server") == 1 then
            cmd = "/opt/homebrew/bin/lua-language-server"
        elseif vim.fn.filereadable("/usr/local/bin/lua-language-server") == 1 then
            cmd = "/usr/local/bin/lua-language-server"
        end
    end

    vim.lsp.config("lua_ls", {
        cmd = cmd ~= "" and { cmd } or nil,
        on_attach = ctx.on_attach,
        capabilities = ctx.capabilities,
        settings = {
            Lua = {
                completion = { callSnippet = "Replace" },
                hint = { enable = true },
                telemetry = { enable = false },
                workspace = { checkThirdParty = false },
                diagnostics = { unusedLocalExclude = { "_*" } },
            },
        },
    })
end

return M
