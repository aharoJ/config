-- path: nvim/lua/settings/files.lua

-- File-handling core options
-- vim.opt.backup = false      -- No *.bak
-- vim.opt.writebackup = false -- No write-backup
-- vim.opt.swapfile = false    -- No *.swp

-- REACT SENSITIVE --
vim.opt.backup      = false
vim.opt.writebackup = false   -- skip atomic swap file dance
vim.opt.backupcopy  = "yes"  -- critical: overwrite existing file
-- ........... --



vim.opt.undofile = true     -- Persistent undo

-- Use XDG-style undo folder inside Neovim’s state dir
local undodir = vim.fn.stdpath("state") .. "/undo"
vim.opt.undodir = undodir
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, "p")
end


-- Create undo directory if it doesn't exist
-- local undodir = vim.fn.expand("~/.vim/undodir")
-- if vim.fn.isdirectory(undodir) == 0 then
--   vim.fn.mkdir(undodir, "p")
-- end

-- Performance / timeout
vim.opt.updatetime = 300 -- CursorHold & completion responsiveness
vim.opt.timeoutlen = 500 -- Mapped-key timeout
vim.opt.ttimeoutlen = 0  -- Key-code timeout (esc, etc.)

-- File reload / auto-save preferences
vim.opt.autoread = true   -- Reload externally-modified files
-- vim.opt.autowrite = false -- Don’t auto-save on :next, :make, etc.

-- Autosave on focus change (write only if buffer changed)
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local autosave = augroup("autosave", { clear = true })

autocmd({ "FocusLost", "WinLeave" }, {
  group = autosave,
  pattern = "*",
  callback = function()
    if vim.bo.modified then
      vim.cmd("silent! write")
    end
  end,
})

-- Shada Persistence
local shada = augroup("shada", { clear = true })
autocmd("VimLeave", {
  group = shada,
  pattern = "*",
  command = "wshada!",
})


-- Auto-reload files when changed externally
local autoread_group = augroup("autoread", { clear = true })
autocmd({ "FocusGained", "CursorHold" }, {
  group = autoread_group,
  pattern = "*",
  callback = function()
    if vim.fn.getcmdwintype() == "" then
      vim.cmd("checktime")
    end
  end,
})


-- vim.api.nvim_create_autocmd("BufWritePost", {
--   pattern = { "*.tsx", "*.ts", "*.jsx", "*.js" },
--   callback = function()
--     -- Trigger browser refresh on save
--     vim.fn.jobstart({"osascript", "-e", 'tell application "Vivaldi" to tell active tab of window 1 to reload'}, {detach = true})
--   end
-- })


-- -- Save immediately when you stop typing or leave insert‑mode
-- local save_grp = vim.api.nvim_create_augroup("autosave_fastrefresh", { clear = true })
-- vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
--   group = save_grp,
--   pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
--   callback = function()
--     if vim.bo.modified then vim.cmd("silent! write") end
--   end,
-- })
