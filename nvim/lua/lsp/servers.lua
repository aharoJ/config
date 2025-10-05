-- path: vim/lua/lsp/servers.lua
local M = {}

-- idk if I shud use this? more complexity; in da long run?
-- local function enable_if_configured(name)
--     local cfgs = vim.lsp.get_configs and vim.lsp.get_configs() or {}
--     if cfgs[name] ~= nil then
--         vim.lsp.enable(name)
--     end
-- end

function M.enable()
	vim.lsp.enable("lua_ls")
	vim.lsp.enable("pyright")
	vim.lsp.enable("ruff")
	-- Web stack:
	vim.lsp.enable("vtsls")
	vim.lsp.enable("eslint")
	vim.lsp.enable("tailwindcss")
	vim.lsp.enable("cssls")
	vim.lsp.enable("html")
	-- vim.lsp.enable("emmet_ls") -- DISABLED
	-- Java handled by jdtls separately
	vim.lsp.enable("taplo") -- TOML
	vim.lsp.enable("yamlls") -- YAML
	vim.lsp.enable("bashls") -- Bash/SH
	vim.lsp.enable("fish_lsp") -- Fish
	vim.lsp.enable("marksman") -- ← add this
end

return M
