-- path: lua/core/files.lua


local M = {}

-- tiny helper
local fn, api, o = vim.fn, vim.api, vim.opt
local function ensure_dir(dir) if fn.isdirectory(dir) == 0 then fn.mkdir(dir, "p") end end
local function map(modes, lhs, rhs, desc, opts)
    opts = opts or {}; opts.silent = (opts.silent ~= false); opts.desc = desc
    for _, m in ipairs(type(modes) == "table" and modes or { modes }) do vim.keymap.set(m, lhs, rhs, opts) end
end

--- Setup high-quality file behavior.
--- @param cfg table|nil { autosave = false|true, autosave_events = {..} }
function M.setup(cfg)
    cfg                   = cfg or {}
    local AUTOSAVE        = cfg.autosave == true
    local AUTOSAVE_EVENTS = cfg.autosave_events or { "FocusLost", "BufLeave", "WinLeave" }

    -- ----- State paths (portable, cache-safe) -----
    local state_dir       = fn.stdpath("state") -- e.g. ~/.local/state/nvim
    local undo_dir        = state_dir .. "/undo"
    local swap_dir        = state_dir .. "/swap"
    local backup_dir      = state_dir .. "/backup"
    local view_dir        = state_dir .. "/view"

    ensure_dir(undo_dir); ensure_dir(swap_dir); ensure_dir(backup_dir); ensure_dir(view_dir)

    -- ----- Persistent undo (close, reopen, still undo/redo) -----
    o.undofile     = true
    o.undodir      = undo_dir
    o.undolevels   = 10000
    o.undoreload   = 10000

    -- ----- Crash/OS safety (keep repo clean) -----
    o.swapfile     = true
    o.directory    = swap_dir .. "//" -- // for unique per-path names
    o.backup       = true
    o.writebackup  = true
    o.backupdir    = backup_dir
    o.backupcopy   = "auto"
    o.backupext    = ".backup"

    -- ----- Encoding & EOL (cross-platform repos) -----
    o.encoding     = "utf-8"
    o.fileencoding = "utf-8"
    o.fileformats  = { "unix", "mac", "dos" }

    -- ----- Pro workflow niceties -----
    o.hidden       = true -- switch buffers without forcing save (keeps undo in memory)
    o.confirm      = true -- dialogs instead of erroring on :q/:w when needed
    o.autoread     = true -- pick up external changes on focus/checktime
    o.updatetime   = 3000 -- conservative (swap/diagnostics timers)
    o.updatecount  = 200

    -- Remember stuff without bloat (marks, registers, etc.)
    o.shada        = { "'1000", "<100", "s20", "h" }

    -- Store & restore view (folds, cursor pos, etc.) per file
    o.viewoptions  = "folds,cursor,curdir,slash,unix"

    -- ----- Autocommands (resilience + VSCode-y feel) -----
    local aug      = api.nvim_create_augroup("core.files", { clear = true })

    -- Re-check external file changes sanely (no spam)
    api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
        group = aug,
        callback = function() if vim.o.buftype == "" then pcall(vim.cmd, "checktime") end end,
    })

    -- Restore last cursor position on reopen (and open folds there)
    api.nvim_create_autocmd("BufReadPost", {
        group = aug,
        callback = function(args)
            if vim.bo[args.buf].filetype:match("^git") then return end
            local mark, last = fn.line([['"]]), fn.line("$")
            if mark > 1 and mark <= last then
                pcall(vim.cmd, "silent! normal! g`\"")
                pcall(vim.cmd, "silent! normal! zv")
            end
        end,
    })

    -- Save/load per-file view (folds, cursor) without touching your repo
    api.nvim_create_autocmd("BufWinLeave", {
        group = aug,
        callback = function(args)
            if vim.bo[args.buf].buftype == "" and fn.filereadable(args.file) == 1 then
                ensure_dir(view_dir); pcall(vim.cmd, "silent! mkview")
            end
        end,
    })
    api.nvim_create_autocmd("BufWinEnter", {
        group = aug,
        callback = function(args)
            if vim.bo[args.buf].buftype == "" and fn.filereadable(args.file) == 1 then
                pcall(vim.cmd, "silent! loadview")
            end
        end,
    })

    -- Ensure dirs exist even if state path changes during run
    api.nvim_create_autocmd("VimEnter", {
        group = aug,
        callback = function()
            ensure_dir(undo_dir); ensure_dir(swap_dir); ensure_dir(backup_dir); ensure_dir(view_dir)
        end,
    })

    -- Create missing parent dirs before writing new files
    api.nvim_create_autocmd("BufWritePre", {
        group = aug,
        callback = function(a)
            local dir = fn.fnamemodify(a.match, ":p:h")
            if fn.isdirectory(dir) == 0 then fn.mkdir(dir, "p") end
        end,
    })

    -- Optional, conservative autosave (off by default)
    if AUTOSAVE then
        api.nvim_create_autocmd(AUTOSAVE_EVENTS, {
            group = aug,
            callback = function()
                if vim.bo.modified and vim.bo.buftype == "" and fn.getcmdwintype() == "" then
                    pcall(vim.cmd, "silent! write")
                end
            end,
            desc = "Autosave (safe events only)",
        })
    end

    -- ----- Mac-style Undo/Redo (with terminal fallbacks) -----
    -- Native Cmd keys require a GUI (Neovide, VimR, Goneovim). For terminals, use the Alt fallbacks.
    map({ "n", "x" }, "<D-z>", "<Cmd>undo<CR>", "Undo (Cmd+Z)")
    map({ "n", "x" }, "<D-S-z>", "<Cmd>redo<CR>", "Redo (Shift+Cmd+Z)")
    map({ "n", "x" }, "<M-z>", "<Cmd>undo<CR>", "Undo (Alt+Z fallback)")
    map({ "n", "x" }, "<M-S-z>", "<Cmd>redo<CR>", "Redo (Alt+Shift+Z fallback)")

    -- Insert mode (stay in insert after action)
    map("i", "<D-z>", "<C-o>u", "Undo (Cmd+Z)")
    map("i", "<D-S-z>", "<C-o><C-r>", "Redo (Shift+Cmd+Z)")
    map("i", "<M-z>", "<C-o>u", "Undo (Alt+Z fallback)")
    map("i", "<M-S-z>", "<C-o><C-r>", "Redo (Alt+Shift+Z fallback)")

    -- Linux/Windows optional fallbacks (comment out if you don’t want):
    if fn.has("mac") == 0 then
        map({ "n", "x" }, "<C-z>", "u", "Undo (Ctrl+Z)")
        map({ "n", "x" }, "<C-y>", "<C-r>", "Redo (Ctrl+Y)")
        map("i", "<C-z>", "<C-o>u", "Undo (Ctrl+Z)")
        map("i", "<C-y>", "<C-o><C-r>", "Redo (Ctrl+Y)")
    end
end

return M
