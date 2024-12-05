-- ---@diagnostic disable: undefined-doc-name
-- return {
-- 	"folke/noice.nvim",
-- 	dependencies = {
-- 		'stevearc/dressing.nvim',
-- 		"MunifTanjim/nui.nvim",
-- 		'rcarriga/nvim-notify'
-- 	},
-- 	enabled = true,
-- 	config = function ()
-- 		require("plugins.ui-configs.dressing")
-- 		require("plugins.ui-configs.noice")
-- 		require("plugins.ui-configs.notify")
-- 	end
-- }

-- lazy.nvim
return {
	"folke/noice.nvim",
	event = "VeryLazy",
	opts = {}, -- add any options here
	dependencies = {
		"MunifTanjim/nui.nvim",
		"rcarriga/nvim-notify",
		"stevearc/dressing.nvim",
	},
	config = function()
		-- require("plugins.ui-configs.dressing")
		require("plugins.ui-configs.notify")
		require("plugins.ui-configs.noice")
	end,
}
