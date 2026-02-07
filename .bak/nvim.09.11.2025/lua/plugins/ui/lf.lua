-- path: nvim/lua/plugins/lf.lua
---@diagnostic disable: undefined-global

return {
    "lmburns/lf.nvim",
    dependencies = {
        {
            "akinsho/toggleterm.nvim",
            version = "*",
            opts = {
                -- keep terminals visible if the process exits, so you can read errors
                close_on_exit = false,
                shade_terminals = false,
                highlights = {
                    Normal      = { link = "Normal" },
                    NormalFloat = { link = "Normal" },
                    FloatBorder = { link = "FloatBorder" },
                },
            },
        },
    },

    cmd = { "Lf" },
    keys = {
        { "<M-o>", "<Cmd>Lf<CR>", mode = "n", desc = "Open lf (file manager)" },
    },

    -- Replacing netrw requires eager-load, but we set this early anyway.
    init = function()
        vim.g.lf_netrw = 1
    end,

    config = function()
        local fn = vim.fn

        -- 1) Check lf is installed and in PATH
        if fn.executable("lf") ~= 1 then
            vim.notify(
                "[lf.nvim] The `lf` binary is not in your PATH. Install it first: https://github.com/gokcehan/lf",
                vim.log.levels.ERROR
            )
            -- Provide a safe fallback command so :Lf doesn't explode
            vim.api.nvim_create_user_command("Lf", function()
                vim.notify("[lf.nvim] Cannot open: `lf` not found", vim.log.levels.ERROR)
            end, {})
            return
        end

        -- 2) Normal setup
        require("lf").setup({
            -- ---------- Behavior ----------
            default_action        = "drop",
            default_actions       = {
                ["<C-t>"] = "tabedit",
                ["<C-x>"] = "split",
                ["<C-v>"] = "vsplit",
                ["<C-o>"] = "tab drop",
            },

            -- ---------- UI ----------
            winblend              = 10,
            dir                   = "", -- ""/nil = CWD, "gwd" = repo root
            direction             = "float",
            border                = "rounded",
            height                = fn.float2nr(fn.round(0.75 * vim.o.lines)),
            width                 = fn.float2nr(fn.round(0.75 * vim.o.columns)),
            escape_quit           = true,
            focus_on_open         = true,
            mappings              = true,
            tmux                  = false,
            default_file_manager  = false,
            disable_netrw_warning = true,

            -- Forward highlight links only
            highlights            = {
                Normal      = { link = "Normal" },
                NormalFloat = { link = "Normal" },
                FloatBorder = { link = "FloatBorder" },
            },

            -- ---------- Layout presets ----------
            layout_mapping        = "<M-u>",
            views                 = {
                { width = 0.800, height = 0.800 },
                { width = 0.600, height = 0.600 },
                { width = 0.950, height = 0.950 },
                { width = 0.500, height = 0.500, col = 0.0, row = 0.0 },
                { width = 0.500, height = 0.500, col = 0.0, row = 0.5 },
                { width = 0.500, height = 0.500, col = 0.5, row = 0.0 },
                { width = 0.500, height = 0.500, col = 0.5, row = 0.5 },
            },
        })

        -- Optional: inside the lf terminal, pressing 'q' quits lf immediately
        vim.api.nvim_create_autocmd("User", {
            pattern = "LfTermEnter",
            callback = function(a)
                vim.keymap.set("t", "q", "q", { buffer = a.buf, nowait = true })
            end,
        })
    end,
}
