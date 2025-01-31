return {
	"folke/noice.nvim",
	event = "VeryLazy",
	opts = {}, -- add any options here
	dependencies = {
		"MunifTanjim/nui.nvim",
		"rcarriga/nvim-notify",
		-- "stevearc/dressing.nvim",
	},
	config = function()
		-- require("plugins.ui-configs.dressing")
		require("plugins.ui-configs.notify")
		require("plugins.ui-configs.noice")
	end,
}
