-- path: nvim/lua/core/paths.lua

-- Copy Full Absolute File-Path
vim.keymap.set("n", "<leader>gP", function()
	local path = vim.fn.expand("%:p")
	vim.fn.setreg("+", path)
	vim.notify("Copied: " .. path, vim.log.levels.INFO)
end, {
	desc = "Copy full absolute path",
})

-- Copy Src Relative Path as Comment
vim.keymap.set("n", "<leader>gp", function()
	local full_path = vim.fn.expand("%:p")
	local src_path = full_path:match("(src/.*)")

	if not src_path then
		vim.notify("Not inside src/ directory", vim.log.levels.WARN)
		return
	end

	local comment_line = "// path: " .. src_path
	vim.fn.setreg("+", comment_line)

	local current_line = vim.fn.line(".")
	vim.fn.append(current_line - 1, comment_line)

	vim.notify("Inserted: " .. comment_line, vim.log.levels.INFO)
end, {
	desc = "Insert src relative path comment",
})

-- Reveal in Finder
vim.keymap.set("n", "<leader>gr", function()
	local file = vim.fn.expand("%:p")
	if file == "" then
		vim.notify("No file to reveal", vim.log.levels.WARN)
		return
	end

	vim.fn.jobstart({ "open", "-R", file }, { detach = true })
	vim.notify("Revealing: " .. file, vim.log.levels.INFO)
end, {
	desc = "Reveal in Finder",
})
