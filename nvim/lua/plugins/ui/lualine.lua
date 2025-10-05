---@diagnostic disable: need-check-nil, undefined-field
-- path: nvim/lua/plugins/ui/lualine.lua

return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },

	init = function()
		-- vim.opt.cmdheight = 0 -- idk if I like this  0:hide | 1:show
		vim.opt.laststatus = 3
		vim.opt.showmode = false
	end,

	config = function()
		-- Fully custom hex theme: colors for active modes + inactive
		local lualine_theme = { -- theme table start
			normal = { -- colors when in NORMAL mode
				a = { fg = "#292a43", bg = "#7c7fca", gui = "bold" }, -- left-most chip (mode)
				b = { fg = "#e3ded7", bg = "#161616" }, -- mid-left group (e.g., git/diags)
				c = { fg = "#e3ded7", bg = "#1c1e2b" }, -- LINE BG COLOR
			}, -- end NORMAL
			insert = { a = { fg = "#292a43", bg = "#6b806b", gui = "bold" } }, -- INSERT chip colors
			visual = { a = { fg = "#292a43", bg = "#d5c28f", gui = "bold" } }, -- VISUAL chip colors
			command = { a = { fg = "#292a43", bg = "#b48284", gui = "bold" } }, -- COMMAND chip colors
			replace = { a = { fg = "#FFFFFF", bg = "#161616", gui = "bold" } }, -- REPLACE chip colors
			inactive = { -- colors when window is unfocused
				a = { fg = "#F54927", bg = "#F54927" }, -- left-most (unused if no 'a' in inactive_sections)
				b = { fg = "#F54927", bg = "#F54927" }, -- mid-left (unused if no 'b' in inactive_sections)
				c = { fg = "#F54927", bg = "#F54927" }, -- center-left (e.g., inactive filename)
			},
			-- Add tabline transparency
			tabline = {
				a = { fg = "#e3ded7", bg = "NONE" }, -- active tab
				b = { fg = "#8a8a8a", bg = "NONE" }, -- inactive tab
				c = { fg = "#e3ded7", bg = "NONE" }, -- tabline fill
			},
		}

		---------------------------------------------------------------------------
		-- Small helpers
		---------------------------------------------------------------------------
		local function in_git_repo()
			return vim.b.gitsigns_head ~= nil
		end

		local function get_lsp_client_names()
			local clients = vim.lsp.get_clients({ bufnr = 0 })
			if not clients or #clients == 0 then
				return ""
			end
			local names, seen = {}, {}
			for _, client in ipairs(clients) do
				local name = client.name
				if name ~= "null-ls" and name ~= "copilot" and not seen[name] then
					table.insert(names, name)
					seen[name] = true
				end
			end
			return table.concat(names, " | ")
		end

		local function macro_recording_status()
			local reg = vim.fn.reg_recording()
			return (reg ~= "") and (" @" .. reg) or ""
		end

		local function dap_current_status()
			local dap = require_safely("dap")
			if not dap or not dap.status then
				return ""
			end
			local s = dap.status()
			return (s and #s > 0) and (" " .. s) or ""
		end

		local function noice_current_mode()
			local noice = require_safely("noice")
			if not noice or not noice.api or not noice.api.statusline then
				return ""
			end
			if noice.api.statusline.mode and noice.api.statusline.mode.has() then
				return noice.api.statusline.mode.get()
			end
			return ""
		end

		local function encoding_if_non_default()
			local enc = (vim.bo.fenc ~= "" and vim.bo.fenc) or vim.o.enc
			return (enc ~= "utf-8") and enc or ""
		end

		local function fileformat_if_non_default()
			local ff = vim.bo.fileformat
			return (ff ~= "unix") and ff or ""
		end

		local function search_count_status()
			if vim.v.hlsearch == 0 then
				return ""
			end
			local ok, sc = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 50 })
			if not ok or not sc or sc.total == 0 then
				return ""
			end
			return string.format(" %d/%d", sc.current or 0, sc.total or 0)
		end

		---------------------------------------------------------------------------
		-- Mode icons (customize these to taste)
		---------------------------------------------------------------------------
		local mode_icon_by_name = {
			["NORMAL"] = "", -- Neovim logo
			["INSERT"] = "", -- pencil
			["VISUAL"] = "", -- eye
			["V-LINE"] = "", -- lines
			["V-BLOCK"] = "▧", -- block
			["SELECT"] = "",
			["REPLACE"] = "",
			["V-REPLACE"] = "",
			["COMMAND"] = "",
			["TERMINAL"] = "",
			["OP"] = "",
		}

		local function add_icon_to_mode(mode_text)
			local icon = mode_icon_by_name[mode_text] or ""
			return string.format("%s %s", icon, mode_text)
		end

		---------------------------------------------------------------------------
		-- Lualine setup
		---------------------------------------------------------------------------
		require("lualine").setup({
			options = {
				theme = lualine_theme,
				globalstatus = true,
				icons_enabled = true,
				-- Use lualine defaults for separators and refresh cadence
				disabled_filetypes = {
					statusline = { "alpha", "starter", "dashboard", "neo-tree", "Outline", "minifiles" },
					winbar = {},
				},
				ignore_focus = { "neo-tree", "NvimTree" },
				always_divide_middle = true,
				always_show_tabline = true,
			},

			sections = {
				lualine_a = {
					{ "mode", fmt = add_icon_to_mode }, -- NORMAL / INSERT / etc + icon
					{ macro_recording_status, padding = { left = 1, right = 0 } },
				},
				lualine_b = {
					{
						"diagnostics", -- lualine diagnostics component
						sources = { "nvim_diagnostic" }, -- use built-in diagnostics source
						colored = true, -- color counts by severity
						diagnostics_color = { -- override per-severity colors (fg)
							-- error = { fg = "#e3ded7" }, -- softer error red (change this)
							-- warn  = { fg = "#e3ded7" }, -- warn yellow
							-- info  = { fg = "#e3ded7" }, -- info blue
							-- hint  = { fg = "#e3ded7" }, -- hint green
						},
						color = { bg = "#454770" }, -- keep bar background consistent
						symbols = { error = " ", warn = " ", info = " ", hint = " " }, -- icons for each severity
						update_in_insert = false, -- avoid flicker while typing
						padding = { left = 1, right = 1 },
						separator = { left = "", right = "" },
					},
				},
				lualine_c = {
					{
						"filename",
						path = 1,
						separator = { left = "", right = "" },
						color = { bg = "#292a43", fg = "#e3ded7" }, -- keep bar background consistent
					},
				},
				lualine_x = {
					{
						function()
							local names = get_lsp_client_names()
							return (names ~= "" and (" " .. names)) or ""
						end,
						-- component_separators = { left = "", right = "" },
						-- section_separators = { left = "", right = "" },
						color = { bg = "#454770", fg = "#e3ded7" }, -- keep bar background consistent
						separator = { left = "", right = "" },
					},
					{ noice_current_mode },
					{ dap_current_status },
					-- { search_count_status },
					{ encoding_if_non_default },
					{ fileformat_if_non_default },
				},
				lualine_y = {},
				lualine_z = { "location" },
			},

			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = {},
			},

			tabline = {
				lualine_a = {
					{
						"buffers",
						show_filename_only = true,
						hide_filename_extension = true,
						show_modified_status = false,
						use_mode_colors = true,
						buffers_color = {
							-- active = { fg = "#292a43", bg = "#9698e3" },
							-- inactive = { fg = "#292a43", bg = "#535586" },
							active = { fg = "#e3ded7", bg = "#535586" },
							inactive = { fg = "#1d1d2f", bg = "#3a3b5e" },
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
						component_separators = { left = "", right = "" },
						section_separators = { left = "", right = "" },
					},
				},
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = {
					{
						"diff",
						colored = true, -- color the text
						symbols = { added = " ", modified = " ", removed = " " },
						diff_color = {
							added = { bg = "#454770", fg = "#a6e3a1" },
							modified = { bg = "#454770", fg = "#f9e2af" },
							removed = { bg = "#454770", fg = "#f38ba8" },
						},
						separator = { left = "", right = "" },
					},
					{
						"branch",
						icon = "",
						color = { bg = "#292a43", fg = "#7c7fca" },
                        -- color = { fg = "#292a43", bg = "#7c7fca", gui = "bold" }, -- left-most chip (mode)
						separator = { left = "", right = "" },
					},
				},
			},

			winbar = {},
			inactive_winbar = {},

			extensions = {
				"quickfix",
				"man",
				"fugitive",
				"lazy",
				"mason",
				"neo-tree",
				"nvim-dap-ui",
				"trouble",
				"oil",
			},
		})
	end,
}
