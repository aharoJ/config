-- path: nvim/lua/core/mute.lua
-- desc: mute/kill kill netrw (turn off default tree)
---@diagnostic disable: undefined-global
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1


--- nvim . 
-- If opening a directory, clear all buffers so you start fresh
-- vim.api.nvim_create_autocmd("VimEnter", {
--     callback = function(data)
--         if vim.fn.isdirectory(data.file) == 1 then
--             -- wipe out the initial no-name buffer
--             vim.cmd("enew") -- create a new empty buffer
--             vim.cmd("bd#") -- then immediately wipe the old [No Name] buffer
--         end
--     end,
-- })
