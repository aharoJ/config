-- Transparent Backgrounds
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "NONE" })
vim.api.nvim_set_hl(0, "MsgArea", { bg = "NONE" })

-- Line Numbers
vim.api.nvim_set_hl(0, "LineNr", { fg = "#7C6C82" })

-- GitSigns (example - customize as needed)
vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { fg = "#735665" })
