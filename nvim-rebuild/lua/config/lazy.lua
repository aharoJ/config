-- path: nvim/lua/config/lazy.lua
-- Description: lazy.nvim bootstrap and setup. No plugin specs here — those live in plugins/.
-- CHANGELOG: 2026-02-03 | Full rewrite: added defaults.lazy, disabled_plugins, ui border | ROLLBACK: Replace with previous lazy.lua


local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"

  local result = vim.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    lazyrepo,
    lazypath,
  }, { text = true }):wait()

  if result.code ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { (result.stderr or ""), "WarningMsg" },
      { (result.stdout or ""), "None" },
    }, true, {})
    return
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
      { import = "plugins" },         -- Loads plugins/init.lua which imports subdirectories
  },
  defaults = {
    lazy = true,                    -- All plugins lazy-loaded by default
  },
  install = {
    colorscheme = { "kanagawa", "habamax" },
  },
  checker = {
    enabled = true,                 -- Auto-check for plugin updates
    notify = false,                 -- Don't spam notifications
  },
  change_detection = {
    notify = false,                 -- Don't notify on config file changes
  },
  performance = {
      rtp = {
          disabled_plugins = {
              "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
              -- "matchit",      -- ← needed for extended % matching
              -- "matchparen",   -- ← needed for bracket highlight pairing  
              -- "netrwPlugin",  -- ← needed for gx, file explorer hijacking
          },
      },
  },
  ui = {
      border = "rounded",             -- Consistent border style (matches vim.o.winborder)
  },
})
