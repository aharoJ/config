-- path: nvim/init.lua
-- Bootstrap Lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out,                            "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Load settings from lua/settings.lua
require("setting")

vim.g.mapleader = " " -- Spacebar as leader key

-- Disable netrw (for neo-tree)
vim.g.loaded_netrw = 1       -- need to load before neo-tree
vim.g.loaded_netrwPlugin = 1 -- need to load before neo-tree

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
        { import = "plugins" },
    },
	-- automatically check for plugin updates
	checker = { enabled = true },
})
-- Misc config
vim.o.cmdheight = 1
