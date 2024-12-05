vim.o.number = true         -- Enable line numbers
vim.o.relativenumber = true -- Enable relative line numbers
vim.o.termguicolors = true

vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")

-------------------       KEYMAPS      ------------------------
-- Paste from clipboard
vim.api.nvim_set_keymap('n', '<Leader>p', '"+p', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>P', '"+P', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<Leader>p', '"+p', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<Leader>P', '"+P', { noremap = true, silent = true })


-- greatest remap ever
-- vim.api.nvim_set_keymap('v', '<leader>p', '"_dp', { noremap = true, silent = true }) -- idk if I like this? 

-- next greatest remap ever
vim.api.nvim_set_keymap('n', '<leader>y', '"+y', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>y', '"+y', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>d', '"_d', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>d', '"_d', { noremap = true, silent = true })

-- switching buffers (tabs)
vim.api.nvim_set_keymap('n', '<S-h>', '<cmd>bprevious<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<S-l>', '<cmd>bnext<CR>', { noremap = true, silent = true })

-- So we can Use <up> <down> instead of tab cycle
vim.api.nvim_set_keymap('c', '<Up>', '<C-p>', { noremap = true })
vim.api.nvim_set_keymap('c', '<Down>', '<C-n>', { noremap = true })

-- File Operations
vim.api.nvim_set_keymap('n', '<Leader>w', ':w<CR>', { noremap = true, silent = true }) -- Save file
vim.api.nvim_set_keymap('n', '<Leader>q', ':q<CR>', { noremap = true, silent = true }) -- Quit
vim.api.nvim_set_keymap('n', '<Leader>x', ':x<CR>', { noremap = true, silent = true }) -- Save and Quit

-- Buffer Navigation
vim.api.nvim_set_keymap('n', '<Leader>bc', ':bd<CR>', { noremap = true, silent = true })       -- Close current buffer
vim.api.nvim_set_keymap('n', '<S-h>', '<cmd>bprevious<CR>', { noremap = true, silent = true }) -- Previous buffer
vim.api.nvim_set_keymap('n', '<S-l>', '<cmd>bnext<CR>', { noremap = true, silent = true })     -- Next buffer

-- sub buffer: Window Management
vim.api.nvim_set_keymap('n', '<Leader>bsv', ':vsplit<CR>', { noremap = true, silent = true }) -- Vertical split
vim.api.nvim_set_keymap('n', '<Leader>bsh', ':split<CR>', { noremap = true, silent = true })   -- Horizontal split
vim.api.nvim_set_keymap('n', '<Leader>bwc', ':close<CR>', { noremap = true, silent = true })   -- Close current window
----------------                              ----------------














-------------------------------------------------------
-- Enable persistent undo
vim.opt.undofile = true

-- Set undo directory to a new location
local undodir = vim.fn.expand('~/.local/share/nvim/undo')  -- Change to your preferred path
vim.opt.undodir = undodir

-- Create the undo directory if it doesn't exist
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, 'p')
end

-- Set the location for swap files to a temporary directory
vim.opt.directory = "/tmp" -- For Unix systems
-- vim.opt.directory = "C:\\Temp"  -- For Windows systems

-- Autosave on focus lost
vim.cmd [[
augroup autosave
  autocmd!
  autocmd FocusLost,WinLeave * silent! wa
augroup END
]]

-- Increase the size of command history stored
vim.opt.shada = "'1000,<50,s10,h"
vim.opt.history = 10000

-- Write to shada file on exit
vim.cmd [[
augroup Shada
  autocmd!
  autocmd VimLeave * wshada!
augroup END
]]
-------------------------------------------------------










-- Trasnaparent
vim.cmd([[
  hi Normal guibg=NONE ctermbg=NONE
  hi SignColumn guibg=NONE
  hi NormalNC guibg=NONE
  hi MsgArea guibg=NONE
  hi TelescopeBorder guibg=NONE
  hi NvimTreeNormal guibg=NONE
  hi VertSplit guibg=NONE
  " ... any other UI elements you want to be transparent
]])









