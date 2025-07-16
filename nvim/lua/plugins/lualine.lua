-- nvim/lua/plugins/lualine.lua

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
			n = { bg = "#8A8DE0", fg = "#1c1e2b" }, -- Normal
			i = { bg = "#77BE84", fg = "#1c1e2b" }, -- Insert
			v = { bg = "#b8b57d", fg = "#1c1e2b" }, -- Visual
			c = { bg = "#b48284", fg = "#1c1e2b" }, -- Command
			[""] = { bg = "#8A8DE0", fg = "#1c1e2b" }, -- Fallback
		}

		-- Helper to get current mode colors
		local function get_mode_color()
			local mode = vim.fn.mode()
			-- Normalize visual modes to single 'v'
			if mode == "V" or mode == "\22" then
				mode = "v"
			end
			return mode_colors[mode] or mode_colors.n
		end

		local default_icon = "  "
		local mode = {
			"mode",
			fmt = function(s)
				local mode_map = {
					["NORMAL"] = "  ",
					["O-PENDING"] = "  ",
					["INSERT"] = "  ",
					["VISUAL"] = "  ",
					["V-BLOCK"] = "  ",
					["V-LINE"] = "  ",
					["V-REPLACE"] = "  ",
					["REPLACE"] = "󰛔  ",
					["COMMAND"] = "  ",
					["SHELL"] = "  ",
					["TERMINAL"] = "  ",
					["EX"] = "  ",
					["S-BLOCK"] = "  ",
					["S-LINE"] = "  ",
					["SELECT"] = "  ",
					["CONFIRM"] = "  ",
					["MORE"] = "  ",
				}
				local icon = mode_map[s] or default_icon
				return icon .. s
			end,
		}

		local diagnostics = {
			"diagnostics",
			symbols = { error = " ", warn = " ", info = " ", hint = " " },
			colored = true, -- Displays diagnostics status in color if set to true.
			update_in_insert = false, -- Update diagnostics in insert mode.
			always_visible = false, -- Show diagnostics even if there are none.
			color = { bg = "#1c1e2b" }, -- <-- pick yours
		}

		local filetype = {
			"filetype",
			colored = true, -- Displays filetype icon in color if set to true
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

		-------------------------------------
		-- Enhanced LSP status component
		local lsp_status = {
			function()
				-- Get current LSP clients
				local buf_clients = vim.lsp.get_clients({ bufnr = 0 })

				if #buf_clients == 0 then
					return "" -- No LSP icon
				end

				-- Server icons mapping
				local server_icons = {
					["null-ls"] = "", -- null-ls icon
					["ts_ls"] = "󰛦", -- TypeScript
					["tailwindcss"] = "󱏿", -- Tailwind CSS
					["copilot"] = "", -- GitHub Copilot
					["lua_ls"] = "", -- Lua
					["pyright"] = "", -- Python
					["bashls"] = "", -- Bash
					["rust_analyzer"] = "", -- Rust
					["omnisharp"] = "󰪮", -- C#
					["stylelint_lsp"] = "", -- CSS LSP
					["jsonls"] = "", -- JSON
					["marksman"] = "󰈔", -- Markdown
					["dockerls"] = "󰡨", -- Docker
					["lemminx"] = "󰈔", -- XML
					["gopls"] = "", -- Go
					["jdtls"] = "", -- Java
					["kotlin_language_server"] = "", -- Kotlin
					["clangd"] = "", -- C/C++
				}

				-- Collect status icons
				local status_icons = {}
				for _, client in ipairs(buf_clients) do
					local icon = server_icons[client.name] or ""
					table.insert(status_icons, icon)
				end

				return table.concat(status_icons, " ")
			end,
			color = function()
				local clients = vim.lsp.get_clients({ bufnr = 0 })
				if #clients == 0 then
					return { fg = "#777777" } -- Gray when no LSP
				end

				-- Check if all LSPs are healthy
				local all_healthy = true
				for _, client in ipairs(clients) do
					if client.health and client.health.is_healthy and not client.health:is_healthy() then
						all_healthy = false
						break
					end
				end

				return all_healthy and { fg = "#77BE84" } or { fg = "#E06C75" } -- Green/Red
			end,
			cond = function()
				-- Only show in normal buffers
				return vim.bo.buftype == ""
			end,
		}

		-- Add this after your lsp_status component definition
		vim.api.nvim_create_autocmd("CursorMoved", {
			callback = function()
				local winbar = vim.fn.winline()
				local lsp_section_start = vim.fn.winwidth(0) - 20 -- Approximate position

				if winbar > lsp_section_start then
					-- NO LONGER SUPPORTED --> vim.lsp.get_active_clients({ bufnr = 0 })
					local clients = vim.lsp.get_clients({ bufnr = 0 })
					if #clients == 0 then
						return
					end

					local server_names = {}
					for _, client in ipairs(clients) do
						table.insert(server_names, client.name)
					end

					vim.api.nvim_echo({ { "LSP: " .. table.concat(server_names, ", "), "Comment" } }, false, {})
				end
			end,
		})

		-------------------------------------
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
				added = " ",
				modified = " ",
				removed = " ",
			},
			color = function()
				local colors = get_mode_color()
				return { bg = colors.bg, fg = colors.fg }
			end,
		}

		-- Get the built-in onedark theme from lualine
		local custom_onedark = require("lualine.themes.onedark")
		-- Customize theme colors
		custom_onedark.normal.a.fg = "#1c1e2b"
		custom_onedark.normal.a.bg = "#8A8DE0"
		custom_onedark.insert.a.fg = "#1c1e2b"
		custom_onedark.insert.a.bg = "#77BE84"
		custom_onedark.visual.a.fg = "#2c3043"
		custom_onedark.visual.a.bg = "#b8b57d"
		custom_onedark.command.a.fg = "#1c1e2b"
		custom_onedark.command.a.bg = "#b48284"
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
				-- lualine_y = { clients_lsp }, -- TESTING DUPLICATE ISSUE
				lualine_y = { lsp_status }, -- TESTING DUPLICATE ISSUE
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
							active = { fg = "#ecce96", bg = "#1c1e2b" },
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
