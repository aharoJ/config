-- path: nvim/lua/config/lazy.lua

---@diagnostic disable: undefined-global
-- Bootstrap lazy.nvim (no specs here)

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Kanagawa-matched highlights for Lazy UI
local function apply_lazy_ui_highlights()
	local ok, K = pcall(require, "kanagawa.colors")
	if not ok then
		return
	end
	local ui = K.setup().theme.ui

	-- Slightly tinted background for the Lazy UI window
	vim.api.nvim_set_hl(0, "LazyNormal", { bg = "none", fg = ui.fg }) -- window fill
	-- Nice, subtle title + headings
	vim.api.nvim_set_hl(0, "LazyH1", { bg = "none", fg = ui.special, bold = true })
	vim.api.nvim_set_hl(0, "LazyH2", { bg = "none", fg = ui.fg, bold = true })
	-- Keep comments/descriptions readable on the tint
	vim.api.nvim_set_hl(0, "LazyComment", { fg = ui.fg_dim, italic = true })
end

-- Re-apply on colorscheme changes (so it stays matched to Kanagawa)
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("LazyUiTint", { clear = true }),
	callback = apply_lazy_ui_highlights,
})

-- Initial apply
apply_lazy_ui_highlights()

-- Setup lazy.nvim
require("lazy").setup({
	ui = { border = "rounded" },

	-- 👇 this silences the “Config Change Detected. Reloading…” spam
	change_detection = {
		enabled = true, -- keep hot-reloads
		notify = false, -- but no echo/ENTER prompts
	},

	-- (optional) also quiet background update checks
	checker = {
		enabled = true,
		notify = false,
	},

	spec = {
		{ import = "plugins" },
		{ import = "plugins.themes" },
		{ import = "plugins.lsp" },
		{ import = "plugins.formatting" },
		{ import = "plugins.linting" },
		{ import = "plugins.autocomplete" },
		{ import = "plugins.ui" },
	},
})
