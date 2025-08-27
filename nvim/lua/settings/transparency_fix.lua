-- path: nvim/lua/settings/transparency_fix.lua

-- Force transparency for ALL UI elements after plugins load
local function force_transparency()
	-- Floating windows
	vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })
	vim.api.nvim_set_hl(0, "FloatBorder", { bg = "NONE" })
	vim.api.nvim_set_hl(0, "FloatTitle", { bg = "NONE" })
	vim.api.nvim_set_hl(0, "NonText", { bg = "NONE", fg = "#7C6C82" }) -- For ~ filler lines; match your LineNr fg
	vim.api.nvim_set_hl(0, "SpecialKey", { bg = "NONE", fg = "#7C6C82" }) -- For listchars/whitespace
end

-- Run immediately
force_transparency()

-- Run after colorscheme changes
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = force_transparency,
	desc = "Force transparency after colorscheme change",
})

-- Run after all plugins are loaded (this is the key part!)
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		-- Use defer with 0 ms for minimal delay while ensuring plugins have loaded
		vim.defer_fn(force_transparency, 0)
	end,
	desc = "Force transparency after all plugins load",
})

-- Also run when lazy.nvim finishes loading plugins
vim.api.nvim_create_autocmd("User", {
	pattern = "LazyDone",
	callback = force_transparency,
	desc = "Force transparency after lazy.nvim loads plugins",
})
