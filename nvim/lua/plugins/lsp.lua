-- path: nvim/lua/plugins/lsp.lua

return {
	{
		-- Community defaults for server definitions; consumed by Neovim's native API
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("lsp").setup()
		end,
	},

	{
		-- LuaLS smarts for editing your Neovim config/plugins (replaces neodev)
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				-- Optional: add libuv types when you touch vim.uv
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},

	{
		-- -- Clean, low-overhead LSP progress notifications
		-- "j-hui/fidget.nvim",
		-- opts = {
		-- 	progress = {
		-- 		suppress_on_insert = true,
		-- 		ignore_empty_message = true,
		-- 		display = { render_limit = 8, done_ttl = 2 },
		-- 	},
		-- 	notification = { window = { winblend = 0 } },
		-- },
	},
	{ "b0o/schemastore.nvim", lazy = true }, -- -- NEW: YAML schema goodness (optional; guarded in yamlls.lua)
}
