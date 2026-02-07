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
            { out,                            "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)


-- Setup lazy.nvim
require("lazy").setup({
    ui = { border = "rounded" },
    spec = {
        { import = "plugins" },
        { import = "plugins.themes" },
        { import = "plugins.lsp" },
        { import = "plugins.lsp.lang" },
        { import = "plugins.formatting" },
        { import = "plugins.linting" },
        { import = "plugins.autocomplete" },
        { import = "plugins.ui" },
    },
})