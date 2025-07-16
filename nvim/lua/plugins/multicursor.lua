-- path: ~/.config/nvim/lua/plugins/multicursor.lua
return {
	"smoka7/multicursors.nvim",
	event = "VeryLazy", -- load after UI is ready
	dependencies = { "nvimtools/hydra.nvim" }, -- pop-up hint window
	opts = { -- ← passed straight to .setup(...)
		updatetime = 40, -- feel snappier than default 50 ms
		nowait = true, -- key-presses don’t wait for timeout
		hint_config = {
			float_opts = { border = "none" },
			position = "bottom",
		},
	},
	cmd = {
		"MCstart",
		"MCvisual",
		"MCclear",
		"MCpattern",
		"MCvisualPattern",
		"MCunderCursor",
	},
	keys = {
		{ "<leader>m", "<cmd>MCstart<cr>", mode = { "n", "v" }, desc = "[multi] add/select next" },
	},
	-- vim.keymap.set("n", "<leader>rp", [[:normal! "0p<CR>]], { desc = "[multi] replace with paste" }),
}

-- apple banana apple orange apple grape
-- this apple is red
-- green apple on the tree
-- I like apple pie
-- apple is my favorite fruit
-- one more apple here
