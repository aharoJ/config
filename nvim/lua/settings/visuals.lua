-- nvim/lua/settings/visuals.lua

-- Visuals
vim.opt.termguicolors = true                      -- Enable 24-bit colours
vim.opt.signcolumn = "yes"                        -- Always show sign column
-- vim.opt.colorcolumn = "100"                       -- Ruler at 100 chars

vim.opt.showmatch = true                          -- Highlight matching brackets
vim.opt.matchtime = 2                             -- How long to show match (×0.1 s)

vim.opt.cmdheight = 1                             -- Height of the command line
vim.opt.completeopt = "menuone,noinsert,noselect" -- Completion behaviour
vim.opt.showmode = false                          -- Hide "-- INSERT --" etc.

vim.opt.pumheight = 10                            -- Popup-menu height
-- vim.opt.pumblend      = 10                     -- Popup-menu transparency OFF BREAKS TRANSPARENCY
vim.opt.winblend = 0                              -- Floating-window transparency

vim.opt.conceallevel = 0                          -- Don’t hide markup by default
vim.opt.concealcursor = ""                        -- Don’t hide cursor-line markup

vim.opt.synmaxcol = 300                           -- Stop syntax highlighting after 300 cols

-- vim.api.nvim_set_hl(0, "LineNr", { fg = "#8a9fe0" })                   -- Line Numbers
-- vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { fg = "#" }) -- GitSigns (example - customize as needed)
