return {
    "nvim-lualine/lualine.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        -- "navarasu/onedark.nvim", -- WE USE INTERNAL INSTEAD! 
    },
    config = function()
        -- require("plugins.themes.onedark")
        -- Define mode colors for all components
        local mode_colors = {
            n    = { bg = "#8A8DE0", fg = "#1c1e2b" }, -- Normal
            i    = { bg = "#77BE84", fg = "#1c1e2b" }, -- Insert
            v    = { bg = "#b8b57d", fg = "#1c1e2b" }, -- Visual
            c    = { bg = "#b48284", fg = "#1c1e2b" }, -- Command
            [''] = { bg = "#8A8DE0", fg = "#1c1e2b" }, -- Fallback
        }

        -- Helper to get current mode colors
        local function get_mode_color()
            local mode = vim.fn.mode()
            -- Normalize visual modes to single 'v'
            if mode == 'V' or mode == '\22' then mode = 'v' end
            return mode_colors[mode] or mode_colors.n
        end

        local default_icon = "  "
        local mode = {
            "mode",
            fmt = function(s)
                local mode_map = {
                    ['NORMAL'] = '  ',
                    ['O-PENDING'] = '  ',
                    ['INSERT'] = '  ',
                    ['VISUAL'] = '  ',
                    ['V-BLOCK'] = '  ',
                    ['V-LINE'] = '  ',
                    ['V-REPLACE'] = '  ',
                    ['REPLACE'] = '󰛔  ',
                    ['COMMAND'] = '  ',
                    ['SHELL'] = '  ',
                    ['TERMINAL'] = '  ',
                    ['EX'] = '  ',
                    ['S-BLOCK'] = '  ',
                    ['S-LINE'] = '  ',
                    ['SELECT'] = '  ',
                    ['CONFIRM'] = '  ',
                    ['MORE'] = '  ',
                }
                local icon = mode_map[s] or default_icon
                return icon .. s
            end,
        }

        local diagnostics = {
            "diagnostics",
            symbols = { error = " ", warn = " ", info = " ", hint = " " },
            colored = true,           -- Displays diagnostics status in color if set to true.
            update_in_insert = false, -- Update diagnostics in insert mode.
            always_visible = false,   -- Show diagnostics even if there are none.
            color = { bg = "#1c1e2b" }, -- <-- pick yours
        }

        local filetype = {
            "filetype",
            colored = true,    -- Displays filetype icon in color if set to true
            icon_only = false, -- Display only an icon for filetype
            icon = { align = "left" },
        }

        local filename = {
            "filename",
            file_status = true,
            newfile_status = false,
            path = 4,
            shorting_target = 40,
            symbols = {
                modified = "[] ",
                readonly = " ",
                unnamed = " [No Name]",
                newfile = " [New File]",
            },
            color = { fg = "#ecce96", bg = "#1c1e2b" },
        }

        -- Cached LSP clients function with buffer variable
        local clients_lsp = {
            function()
                return vim.b.lsp_clients and " " .. table.concat(vim.b.lsp_clients, "|") or ""
            end,
            color = function()
                local colors = get_mode_color()
                return { bg = colors.bg, fg = colors.fg }
            end
        }

        -- Update LSP clients cache on attach/detach
        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                local clients = vim.lsp.get_clients({ bufnr = args.buf })
                vim.b.lsp_clients = vim.tbl_map(function(client)
                    return client.name
                end, clients)
            end,
        })

        vim.api.nvim_create_autocmd("LspDetach", {
            callback = function(args)
                vim.b.lsp_clients = nil
            end,
        })

        local help = { sections = { lualine_a = { { "filetype", colored = false } } }, filetypes = { "help" } }
        local alpha = {
            sections = {
                lualine_a = { mode },
                lualine_b = { "git_branch" },
                lualine_z = { "hostname" },
            },
            filetypes = { "alpha" },
        }
        local dashboard = {
            sections = {
                lualine_a = { mode },
                lualine_b = { "git_branch" },
                lualine_z = { filetype },
            },
            filetypes = { "dashboard" },
        }

        local telescope = {
            sections = {
                lualine_a = { mode },
                lualine_x = { filetype },
            },
            filetypes = { "TelescopePrompt" },
        }

        -- Git branch with dynamic command-mode coloring
        local git_branch = {
            "branch",
            icon = "",
            color = function()
                local colors = get_mode_color()
                return { bg = colors.bg, fg = colors.fg }
            end,
        }

        -- Git differences with dynamic command-mode coloring
        local git_difference = {
            "diff",
            colored = false,
            symbols = {
                added    = ' ',
                modified = ' ',
                removed  = ' ',
            },
            color = function()
                local colors = get_mode_color()
                return { bg = colors.bg, fg = colors.fg }
            end,
        }

        -- Get the built-in onedark theme from lualine
        local custom_onedark = require('lualine.themes.onedark')
        -- Customize theme colors
        custom_onedark.normal.a.fg = "#1c1e2b"; custom_onedark.normal.a.bg = "#8A8DE0"
        custom_onedark.insert.a.fg = "#1c1e2b"; custom_onedark.insert.a.bg = "#77BE84"
        custom_onedark.visual.a.fg = "#2c3043"; custom_onedark.visual.a.bg = "#b8b57d"
        custom_onedark.command.a.fg = "#1c1e2b"; custom_onedark.command.a.bg = "#b48284"
        custom_onedark.command = custom_onedark.command
        custom_onedark.shell = custom_onedark.normal
        custom_onedark.ex = custom_onedark.normal

        require("lualine").setup({
            options = {
                icons_enabled = true,
                theme = custom_onedark,
                component_separators = { left = "  ", right = "  " },
                section_separators = { left = "", right = "" },
                disabled_filetypes = {},
                always_divide_middle = true,
                globalstatus = true,
                refresh = {
                    statusline = 1000,
                    tabline = 10,
                    winbar = 1000,
                },
            },
            sections = {
                lualine_a = { mode },
                lualine_b = { diagnostics },
                lualine_c = { filename },
                lualine_x = {
                    {
                        require("noice").api.status.mode.get,
                        cond = require("noice").api.status.mode.has,
                        color = { link = "lualine_b_diff_added_insert" },
                    },
                    "selectioncount",
                    filetype,
                },
                lualine_y = { clients_lsp },
                lualine_z = { "location" },
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = { filename },
                lualine_x = { "location" },
                lualine_y = {},
                lualine_z = {},
            },
            tabline = {
                lualine_a = {
                    {
                        "buffers",
                        show_filename_only = true,
                        hide_filename_extension = true,
                        show_modified_status = true,
                        use_mode_colors = true,
                        buffers_color = {
                            active   = { fg = "#ecce96", bg = "#1c1e2b" },
                            inactive = { fg = "#8e7c5a", bg = "#333540" },
                        },
                        mode = 0,
                        max_length = vim.o.columns * 2 / 3,
                        filetype_names = {
                            TelescopePrompt = "Telescope",
                            dashboard = "Dashboard",
                            packer = "Packer",
                            fzf = "FZF",
                            alpha = "Alpha",
                        },
                        symbols = {
                            modified = " ●",
                            alternate_file = "#",
                            directory = "",
                        },
                    },
                },
                lualine_z = {
                    git_difference,
                    git_branch,
                },
            },
            extensions = {
                "toggleterm",
                "trouble",
                "lazy",
                "nvim-tree",
                help,
                alpha,
                "quickfix",
                dashboard,
                telescope,
            },
        })
    end,
}
