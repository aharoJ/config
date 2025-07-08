return
{
    "folke/which-key.nvim",
    -- dependencies = { 'echasnovski/mini.nvim', version = false },
    event = "VeryLazy",
    init = function()
        vim.o.timeout = true
        vim.o.timeoutlen = 300
    end,
    opts = {
        -- Plugin settings
        plugins = {
            marks = true,   -- Enable mark plugin
            registers = true, -- Enable registers plugin
            spelling = {
                enabled = true, -- Enable spelling suggestions
                suggestions = 20, -- Number of suggestions
            },
            presets = {
                operators = true, -- Help for operators (d, y, etc.)
                motions = true, -- Help for motions
                text_objects = true, -- Help for text objects
                windows = true, -- Help for <c-w> bindings
                nav = true,    -- Misc navigation bindings
                z = true,      -- Help for z-prefixed bindings (folds, etc.)
                g = true,      -- Help for g-prefixed bindings
            },
        },

        -- Icons for the popup
        icons = {
            breadcrumb = "»", -- Symbol for active key combo
            separator = "➜", -- Symbol between key and label
            group = "+", -- Symbol for groups
        },

        -- Key bindings within the popup
        keys = {
            scroll_down = "<c-d>", -- Scroll down in popup
            scroll_up = "<c-u>", -- Scroll up in popup
        },

        -- Window settings
        win = {
            border = "none",      -- Border style
            padding = { 1, 2, 1, 2 }, -- Padding [top, right, bottom, left]
            wo = {
                winblend = 0,     -- Transparency (0 = opaque)
            },
            zindex = 1000,        -- Window stacking order
        },

        -- Layout settings
        layout = {
            height = { min = 4, max = 30 }, -- Min/max height of popup
            width = { min = 4, max = 25 }, -- Min/max width of columns
            spacing = 3,                -- Spacing between columns
            align = "center",           -- Column alignment
        },

        -- General settings
        show_help = true, -- Show help message in command line
        show_keys = true, -- Show pressed key in command line
        triggers = {    -- Explicitly set triggers as a table
            { "<auto>", mode = "nixsotc" },
        },
        disable = {
            buftypes = {}, -- Disable for specific buffer types
            filetypes = {}, -- Disable for specific filetypes
        },

        -- Your keybinding descriptions
        spec = {
            -- Single character mappings
            { "<leader>e", desc = "NeoTree", mode = "n" },
            { "<leader>/", desc = "Comment", mode = "n" },
            { "<leader>q", desc = "Quit",    mode = "n" },

            -- Buffer group
            -- { "<leader>b", group = "Buffer", mode = "n" },
            -- { "<leader>bc", desc = "Close Buffer", mode = "n" },
            -- { "<leader>bn", desc = "Next Buffer", mode = "n" },
            -- { "<leader>bp", desc = "Previous Buffer", mode = "n" },
            -- { "<leader>bsv", desc = "Split Vertical", mode = "n" },
            -- { "<leader>bsh", desc = "Split Horizontal", mode = "n" },
            -- { "<leader>bwc", desc = "Close Window", mode = "n" },
        },
    },
}
