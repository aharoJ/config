vim.o.number = true -- Enable line numbers
vim.o.relativenumber = true -- Enable relative line numbers
vim.o.termguicolors = true
-- vim.g.base16colorspace = 256 -- NEW MAYBE DELETE
vim.o.wrap = false
vim.o.hidden = true

vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")

-------------------       KEYMAPS      ------------------------
vim.api.nvim_set_keymap("n", "<Leader>p", '"+p', { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<Leader>p", '"+p', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>P", '"+P', { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<Leader>P", '"+P', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('v', '<Leader>p', '"_dp', { noremap = true, silent = true })

-- next greatest remap ever
vim.api.nvim_set_keymap("n", "<leader>y", '"+y', { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader>y", '"+y', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>d", '"_d', { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader>d", '"_d', { noremap = true, silent = true })

-- So we can Use <up> <down> instead of tab cycle
vim.api.nvim_set_keymap("c", "<Up>", "<C-p>", { noremap = true })
vim.api.nvim_set_keymap("c", "<Down>", "<C-n>", { noremap = true })

-- File Operations
vim.api.nvim_set_keymap("n", "<Leader>w", ":w<CR>", { noremap = true, silent = true }) -- Save file
vim.api.nvim_set_keymap("n", "<Leader>q", ":q!<CR>", { noremap = true, silent = true }) -- Quit
vim.api.nvim_set_keymap("n", "<Leader>Q", ":qa!<CR>", { noremap = true, silent = true }) -- Quit ALL
vim.api.nvim_set_keymap("n", "<Leader>x", ":x<CR>", { noremap = true, silent = true }) -- Save and Quit

-- Group > <
vim.api.nvim_set_keymap("x", ">", ">gv", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "<", "<gv", { noremap = true, silent = true })

-- remove shift J weird behavior
vim.api.nvim_set_keymap("n", "J", "<NOP>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "J", "<NOP>", { noremap = true, silent = true })

-- vim.api.nvim_command('!xset r rate 1 900')
----------------                              ----------------

-------------------       BUFFERS      ------------------------
vim.api.nvim_set_keymap("n", "<S-h>", "<cmd>bprevious<CR>", { noremap = true, silent = true }) -- buffer previous
vim.api.nvim_set_keymap("n", "<S-l>", "<cmd>bnext<CR>", { noremap = true, silent = true }) -- buffer next
vim.api.nvim_set_keymap("n", "<leader>bc", "<cmd>bd<CR>", { noremap = true, silent = true }) -- buffer close

-- sub buffer: Window Management
vim.api.nvim_set_keymap("n", "<Leader>bsv", ":vsplit<CR>", { noremap = true, silent = true }) -- Vertical split
vim.api.nvim_set_keymap("n", "<Leader>bsh", ":split<CR>", { noremap = true, silent = true }) -- Horizontal split
vim.api.nvim_set_keymap("n", "<Leader>bwc", ":close<CR>", { noremap = true, silent = true }) -- Close current window

vim.api.nvim_set_keymap("n", "<C-T>", "<Nop>", { noremap = true, silent = true }) -- idk
vim.api.nvim_set_keymap("n", "<D-T>", "<Nop>", { noremap = true, silent = true }) -- idk
-- vim.g.neovide_input_macos_alt_is_meta = true -- Use alt as meta key -- did not work
----------------                              ----------------

-------------------       TREESITTER      ------------------------
vim.api.nvim_set_keymap("n", "<Leader>mm", ":Inspect<CR>", { noremap = true, silent = true }) -- For  TreeSitter Inspect
----------------                              ----------------

-------------------       MARKDOWN PREVIEW      ------------------------
vim.api.nvim_set_keymap("n", "<Space>cP", ":w!<CR>:!npx prettier --check %<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Space>cp", ":w!<CR>:!npx prettier % --write <CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Space>mp", ":MarkdownPreviewToggle<CR>", { noremap = true, silent = true })
----------------                              ----------------

vim.api.nvim_set_keymap("n", "<F8>", ":terminal npm run dev<CR>", { noremap = true, silent = true })



-------------------       RUST RUN      ------------------------
vim.api.nvim_set_keymap("n", "<Space>rr", ":RustRun<CR>", { noremap = true, silent = true })
----------------                              ----------------





vim.o.showmode = false -- remove -- INSERT -- VISUAL -- ...








-------------------------------------------------------
-- Enable persistent undo
vim.opt.undofile = true

-- Set undo directory to a new location
local undodir = vim.fn.expand("~/.local/share/nvim/undo") -- Change to your preferred path
vim.opt.undodir = undodir

-- Create the undo directory if it doesn't exist
if vim.fn.isdirectory(undodir) == 0 then
	vim.fn.mkdir(undodir, "p")
end

-- Set the location for swap files to a temporary directory
vim.opt.directory = "/tmp" -- For Unix systems
-- vim.opt.directory = "C:\\Temp"  -- For Windows systems

-- Autosave on focus lost
vim.cmd([[
augroup autosave
  autocmd!
  autocmd FocusLost,WinLeave * silent! wa
augroup END
]])

-- Increase the size of command history stored
vim.opt.shada = "'1000,<50,s10,h"
vim.opt.history = 10000

-- Write to shada file on exit
vim.cmd([[
augroup Shada
  autocmd!
  autocmd VimLeave * wshada!
augroup END
]])
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

-- Set the color for the line numbers
vim.cmd([[
  highlight LineNr guifg=#7C6C82 ctermfg=LightGrey " teal soft purple-pinkish
  " highlight LineNr guifg=#6C7282 ctermfg=LightGrey " gray-blueish
  " highlight LineNr guifg=#A37C7C ctermfg=LightGrey " a nice pink
]])

-- vim.cmd [[
--   highlight Comment guifg=#D2E59D ctermfg=Red
-- ]]

vim.cmd([[
  highlight GitSignsCurrentLineBlame guifg=#735665 ctermfg=Red
  " highlight GitSignsAdd guifg=#D2E59D ctermfg=Red
  " highlight GitSignsChange guifg=#D2E59D ctermfg=Red
  " highlight GitSignsDelete guifg=#D2E59D ctermfg=Red
  " highlight GitSignsTopdelete guifg=#D2E59D ctermfg=Red
  " highlight GitSignsChangedelete guifg=#D2E59D ctermfg=Red
  " highlight GitSignsUntracked guifg=#D2E59D ctermfg=Red
  " highlight GitSignsAddNr guifg=#D2E59D ctermfg=Red
  " highlight GitSignsChangeNr guifg=#D2E59D ctermfg=Red
  " highlight GitSignsDeleteNr guifg=#D2E59D ctermfg=Red
  " highlight GitSignsTopdeleteNr guifg=#D2E59D ctermfg=Red
  " highlight GitSignsChangedeleteNr guifg=#D2E59D ctermfg=Red
  " highlight GitSignsUntrackedNr guifg=#D2E59D ctermfg=Red
  " highlight GitSignsAddLn guifg=#D2E59D ctermfg=Red
  " highlight GitSignsChangeLn guifg=#D2E59D ctermfg=Red
  " highlight GitSignsChangedeleteLn guifg=#D2E59D ctermfg=Red
  " highlight GitSignsUntrackedLn guifg=#D2E59D ctermfg=Red
  " highlight GitSignsAddPreview guifg=#D2E59D ctermfg=Red
  " highlight GitSignsDeletePreview guifg=#D2E59D ctermfg=Red
  " highlight GitSignsAddInline guifg=#D2E59D ctermfg=Red
  " highlight GitSignsDeleteInline guifg=#D2E59D ctermfg=Red
  " highlight GitSignsChangeInline guifg=#D2E59D ctermfg=Red
  " highlight GitSignsAddLnInline guifg=#D2E59D ctermfg=Red
  " highlight GitSignsChangeLnInline guifg=#D2E59D ctermfg=Red
  " highlight GitSignsDeleteLnInline guifg=#D2E59D ctermfg=Red
  " highlight GitSignsDeleteVirtLn guifg=#D2E59D ctermfg=Red
  " highlight GitSignsDeleteVirtLnInLine guifg=#D2E59D ctermfg=Red
  " highlight GitSignsVirtLnum guifg=#D2E59D ctermfg=Red
]])
