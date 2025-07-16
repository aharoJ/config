-- path: nvim/lua/settings/options.lua

-- Basic Editor Options
vim.opt.number = true         -- Show absolute line numbers
vim.opt.relativenumber = true -- Show relative line numbers
vim.opt.cursorline = true     -- Highlight the current line
vim.opt.wrap = false          -- Disable line-wrapping
vim.opt.scrolloff = 10        -- Keep 10 lines above/below cursor TEST
vim.opt.sidescrolloff = 8     -- Keep 8 cols left/right of cursor TEST

vim.opt.hidden = true
vim.opt.showmode = false
vim.opt.wrap = false -- Disable line-wrapping

-- Indentation
vim.opt.tabstop = 2        -- Tab width
vim.opt.shiftwidth = 2     -- Indent width
vim.opt.softtabstop = 2    -- Soft tab stop
vim.opt.expandtab = true   -- Use spaces instead of tabs
vim.opt.smartindent = true -- Smart auto-indenting
vim.opt.autoindent = true  -- Copy indent from current line

-- Undo/Backup
vim.opt.undofile = true
vim.opt.undodir = vim.fn.expand("~/.local/share/nvim/undo")
vim.opt.directory = "/tmp" -- Swap files

-- Search
vim.opt.ignorecase = true -- Case-insensitive by default
vim.opt.smartcase = true  -- Override if search has capitals
vim.opt.hlsearch = true   -- Highlights after search
vim.opt.incsearch = true  -- Show matches as you type

-- History
vim.opt.shada = "'1000,<50,s10,h"
vim.opt.history = 10000

-- -- Disable J key
-- local autocmd = vim.api.nvim_create_autocmd
-- autocmd("FileType", {
--   pattern = "*",
--   callback = function()
--     vim.keymap.set({ "n", "v" }, "J", "<NOP>", { buffer = true })
--   end,
-- })

-- Behavior settings
vim.opt.hidden = true                  -- Allow hidden buffers
vim.opt.errorbells = false             -- No error bells
vim.opt.backspace = "indent,eol,start" -- Better backspace behavior
vim.opt.autochdir = false              -- Don't auto change directory
vim.opt.iskeyword:append("-")          -- Treat dash as part of word
vim.opt.path:append("**")              -- include subdirectories in search
vim.opt.selection = "exclusive"        -- Selection behavior
vim.opt.mouse = "a"                    -- Enable mouse support
-- vim.opt.clipboard:append("unnamedplus")            -- Use system clipboard
vim.opt.modifiable = true              -- Allow buffer modifications
vim.opt.encoding = "UTF-8"             -- Set encoding

-- Command-line completion
vim.opt.wildmenu = true
vim.opt.wildmode = "longest:full,full"
vim.opt.wildignore:append({ "*.o", "*.obj", "*.pyc", "*.class", "*.jar" })
