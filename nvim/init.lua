-- Load settings from lua/settings.lua
require("settings")

vim.g.mapleader = " " -- Spacebar as leader key

-- Bootstrap Lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- Disable netrw (for neo-tree)
vim.g.loaded_netrw = 1 -- need to load before neo-tree
vim.g.loaded_netrwPlugin = 1 -- need to load before neo-tree

-- Load plugins from lua/plugins.lua
require("lazy").setup("plugins", {
	change_detection = {
		notify = false,
	},
})

-- Misc config
vim.o.cmdheight = 1
