-- path: lua/core/buffer_status.lua
---@diagnostic disable: param-type-mismatch
local M = {}

-- Hack-style glyphs (requires Nerd Font)
local ICONS = {
	saved = "",
	scratch = "",
	readonly = "",
	modified = "",
}

local function buffer_status_line(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	local modified = vim.bo[buf].modified
	local listed = vim.bo[buf].buflisted
	local readonly = vim.bo[buf].readonly
	local short = (#name > 0) and vim.fn.fnamemodify(name, ":t") or "[No Name]"

	local icon
	if readonly then
		icon = ICONS.readonly
	elseif modified then
		icon = ICONS.modified
	elseif listed then
		icon = ICONS.saved
	else
		icon = ICONS.scratch
	end

	local flag = modified and "[+]" or ""
	local path = (#name > 0) and vim.fn.fnamemodify(name, ":~:.") or ""
	return string.format("%-3s %-25s %s %s", icon, short, flag, path)
end

function M.show_buffers()
	local bufs = vim.api.nvim_list_bufs()
	local lines = {}
	for _, b in ipairs(bufs) do
		if vim.api.nvim_buf_is_loaded(b) then
			table.insert(lines, buffer_status_line(b))
		end
	end

	if #lines == 0 then
		vim.notify("No active buffers.", vim.log.levels.INFO, { title = "Buffers" })
		return
	end

	table.insert(lines, 1, string.rep("─", 60))
	table.insert(lines, 1, string.format("%-3s %-25s %-5s %s", "", "Name", "Flag", "Path"))
	table.insert(lines, 2, string.rep("─", 60))

	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, {
		title = "Open Buffers",
		timeout = 6000,
	})
end

vim.api.nvim_create_user_command("ZBuffers", M.show_buffers, {})
vim.keymap.set("n", "<leader>zb", ":ZBuffers<CR>", { desc = "Show open buffers" })

return M
