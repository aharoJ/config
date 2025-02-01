return {
	"folke/noice.nvim",
	event = "VeryLazy",
	opts = {}, -- add any options here
	dependencies = {
		"MunifTanjim/nui.nvim", -- needed dependecy 
		"rcarriga/nvim-notify",
	},
	config = function()
		require("plugins.ui-configs.notify")
		require("plugins.ui-configs.noice")
	end,
}
