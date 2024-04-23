-- Create an augroup for fold persistence
vim.api.nvim_create_augroup("remember_folds", { clear = true })

-- This autocommand automatically saves the fold state of a buffer when it's closed.
-- It only does so if there's a valid file path associated with the buffer.
vim.api.nvim_create_autocmd("BufWinLeave", {
  group = "remember_folds",
  pattern = "*",
  callback = function()
    if vim.fn.expand('%:p') ~= "" then
      vim.cmd("mkview") -- Save the current view (folds, cursor position, etc.)
    end
  end,
})

-- This autocommand automatically restores the fold state of a buffer when it's opened.
-- It only does so if there's a valid file path associated with the buffer.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = "remember_folds",
  pattern = "*",
  callback = function()
    if vim.fn.expand('%:p') ~= "" then
      vim.cmd("silent! loadview") -- Restore the saved view if it exists
    end
  end,
})
