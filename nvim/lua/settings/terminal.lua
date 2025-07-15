-- ============================================================================
-- FLOATING TERMINAL (Fixed)
-- ============================================================================

local terminal_state = {
    buf = nil,
    win = nil,
    job_id = nil,
    is_open = false
}

-- Create highlight groups
vim.api.nvim_set_hl(0, "FloatingTerminalNormal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "FloatingTerminalBorder", { fg = "#569CD6", bg = "NONE" })

local function FloatingTerminal()
    -- Toggle closed if already open
    if terminal_state.is_open and vim.api.nvim_win_is_valid(terminal_state.win) then
        vim.api.nvim_win_close(terminal_state.win, true)
        terminal_state.is_open = false
        return
    end

    -- Create new buffer if needed
    if not terminal_state.buf or not vim.api.nvim_buf_is_valid(terminal_state.buf) then
        terminal_state.buf = vim.api.nvim_create_buf(false, true)

        -- Set safe buffer options
        vim.api.nvim_buf_set_option(terminal_state.buf, 'bufhidden', 'hide')
        vim.api.nvim_buf_set_option(terminal_state.buf, 'swapfile', false)
        vim.api.nvim_buf_set_option(terminal_state.buf, 'buflisted', false)
    end

    -- Calculate window dimensions
    local width = math.min(math.floor(vim.o.columns * 0.9), 120)
    local height = math.min(math.floor(vim.o.lines * 0.8), 30)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Create floating window
    local win_opts = {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = " Terminal ",
        title_pos = "center",
        noautocmd = true,
    }

    terminal_state.win = vim.api.nvim_open_win(terminal_state.buf, true, win_opts)

    -- Window styling
    vim.api.nvim_win_set_option(terminal_state.win, 'winblend', 0)
    vim.api.nvim_win_set_option(terminal_state.win, 'winhighlight',
        'Normal:FloatingTerminalNormal,FloatBorder:FloatingTerminalBorder')

    -- Window options
    vim.api.nvim_win_set_option(terminal_state.win, 'number', false)
    vim.api.nvim_win_set_option(terminal_state.win, 'relativenumber', false)
    vim.api.nvim_win_set_option(terminal_state.win, 'signcolumn', 'no')
    vim.api.nvim_win_set_option(terminal_state.win, 'cursorline', false)

    -- Start terminal if not running
    if not vim.b.term_started then
        terminal_state.job_id = vim.fn.termopen(os.getenv("SHELL") or vim.o.shell, {
            on_exit = function()
                vim.schedule(function()
                    if terminal_state.is_open then
                        CloseFloatingTerminal()
                    end
                end)
            end
        })
        vim.b.term_started = true
    end

    terminal_state.is_open = true
    vim.cmd("startinsert")

    -- Close terminal when process exits
    vim.api.nvim_create_autocmd("TermClose", {
        buffer = terminal_state.buf,
        callback = CloseFloatingTerminal,
        once = true
    })

    -- Clean up when window is closed
    vim.api.nvim_create_autocmd("WinClosed", {
        callback = function(args)
            if tonumber(args.match) == terminal_state.win then
                terminal_state.is_open = false
                terminal_state.win = nil
            end
        end
    })
end

function CloseFloatingTerminal()
    if terminal_state.is_open and terminal_state.win and vim.api.nvim_win_is_valid(terminal_state.win) then
        vim.api.nvim_win_close(terminal_state.win, true)
    end
    terminal_state.is_open = false
end

-- Key mappings
vim.keymap.set("n", "<leader>tt", FloatingTerminal, {
    noremap = true,
    silent = true,
    desc = "Toggle floating terminal"
})

vim.keymap.set("t", "<Esc>", function()
    if terminal_state.is_open then
        vim.api.nvim_win_close(terminal_state.win, true)
        terminal_state.is_open = false
    end
end, {
    noremap = true,
    silent = true,
    desc = "Close floating terminal"
})

-- Close terminal when leaving Neovim
vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = CloseFloatingTerminal
})
