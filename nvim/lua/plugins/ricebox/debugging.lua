return {
	"mfussenegger/nvim-dap",
	dependencies = {
		"theHamsta/nvim-dap-virtual-text",
		"rcarriga/nvim-dap-ui",
		"nvim-neotest/nvim-nio",
		-- -- "folke/neodev.nvim" -- neodev recommended HERE thats why we added it to begin with
	},
	config = function()
		require("nvim-dap-virtual-text").setup()
		require("dapui").setup()

		-------------------    DAP KEYBINDS    ------------------------
		vim.keymap.set("n", "<Leader>dt", ":DapToggleBreakpoint<CR>")
		vim.keymap.set("n", "<Leader>dc", ":DapContinue<CR>")
		vim.keymap.set("n", "<Leader>dx", ":DapTerminate<CR>")
		vim.keymap.set("n", "<Leader>do", ":DapStepOver<CR>")
		vim.keymap.set("n", "<Leader>di", ":DapStepInto<CR>")
		vim.keymap.set("n", "<Leader>dO", ":DapStepOut<CR>")
		vim.keymap.set("n", "<leader>dd", require("dapui").toggle)
		vim.keymap.set("n", "<leader>dD", ":DapVirtualTextToggle<CR>")
		-- vim.keymap.set("n", "<leader>__", ":DapRestartFrame<CR>")
		-- vim.keymap.set("n", "<leader>__", ":DapToggleRepl<CR>")
		-- vim.keymap.set("n", "<leader>__", ":DapSetLogLevel<CR>")
		-- vim.keymap.set("n", "<leader>__", ":DapLoadLaunchJSON<CR>")
		-- vim.keymap.set("n", "<leader>__", ":DapShowLog<CR>")
		-- vim.keymap.set("n", "<leader>__", ":DapVirtualTextToggle<CR>")
		----------------                              ----------------
	end,
}
