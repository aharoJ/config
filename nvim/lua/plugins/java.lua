-- path: ~/.config/nvim/lua/plugins/java.lua
return {
	{
		"mfussenegger/nvim-jdtls",
		ft = { "java" },
		dependencies = {
			"neovim/nvim-lspconfig",
			-- completion caps if you use cmp (harmless if present)
			"hrsh7th/cmp-nvim-lsp",
			-- Debug & tests (recommended, but lazy)
			{ "mfussenegger/nvim-dap", lazy = true },
			{
				"rcarriga/nvim-dap-ui",
				lazy = true,
				dependencies = { "nvim-neotest/nvim-nio" },
				config = true,
			},
			{ "theHamsta/nvim-dap-virtual-text", lazy = true, config = true },
		},
		config = function()
			-- keep jdtls separate from mason-lspconfig; start per FileType
			require("core.jdtls").setup_autocmd()
		end,
	},
}
