local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Autosave
local autosave = augroup("autosave", { clear = true })
autocmd({ "FocusLost", "WinLeave" }, {
    group = autosave,
    pattern = "*",
    command = "silent! wa",
})

-- Shada Persistence
local shada = augroup("shada", { clear = true })
autocmd("VimLeave", {
    group = shada,
    pattern = "*",
    command = "wshada!",
})

-- Disable J key
autocmd("FileType", {
    pattern = "*",
    callback = function()
        vim.keymap.set({ "n", "v" }, "J", "<NOP>", { buffer = true })
    end
})
