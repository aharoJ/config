vim.g.mapleader = " " -- Spacebar as leader key
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

vim.g.loaded_netrw = 1 -- need to load before neo-tree
vim.g.loaded_netrwPlugin = 1 -- need to load before neo-tree
require("lazy").setup("plugins", {
	change_detection = {
		notify = false,
	},
})

require("settings")
vim.o.cmdheight = 1

-- HELLO WORLD! (:
