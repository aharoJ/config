-- Copy Full File-Path
vim.keymap.set("n", "<leader>gp", function()
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
vim.keymap.set("n", "<leader>gP", reveal_in_file_manager, {
	desc = "Reveal in Finder/Explorer",
})
