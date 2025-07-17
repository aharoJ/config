-- path: /Users/aharo/.config/nvim/lua/settings/functions.lua

-- Highlight yanked text
local augroup = vim.api.nvim_create_augroup("UserConfig", {})

vim.api.nvim_create_autocmd("TextYankPost", {
	group = augroup,
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- Return to last edit position when opening files
vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup,
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lcount = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- ============================================================================
-- USEFUL FUNCTIONS
-- ============================================================================

-- Copy Full File-Path
vim.keymap.set("n", "gp", function()
	local path = vim.fn.expand("%:p")
	vim.fn.setreg("+", path)
	print("file:", path)
end, {
	desc = "[options] get pwd",
})

-- Reveal in Finder/Explorer function
local function reveal_in_file_manager()
	local file = vim.fn.expand("%:p")
	if file == "" then
		vim.notify("No file to reveal (unsaved buffer?)", vim.log.levels.WARN)
		return
	end

	if vim.fn.has("mac") == 1 then
		vim.fn.jobstart({ "open", "-R", file }, { detach = true })
	else
		-- Linux: open parent directory
		local dir = vim.fn.fnamemodify(file, ":h")
		vim.fn.jobstart({ "xdg-open", dir }, { detach = true })
	end
	vim.notify("Revealing: " .. file, vim.log.levels.INFO)
end

-- Keymap with improved description
vim.keymap.set("n", "gP", reveal_in_file_manager, {
	desc = "Reveal in Finder/Explorer",
})
