return {
	{
		-- "RRethy/base16-nvim", -- enhanches themes?
	},
	{
		"nvim-lualine/lualine.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"RRethy/base16-nvim", -- enhanches themes?
		},
		config = function()
			require("lualine").setup({

				-------------------    OPTIONS    ------------------------
				options = {
					icons_enabled = true,
					-- theme = 'auto',
					theme = "jellybeans",
					-- theme = "seoul256",
					-- theme = "base16",
					-- quiet = true, -- Add this to suppress warning messages
					component_separators = { left = "", right = "" },
					section_separators = { left = "", right = "" },
					disabled_filetypes = {
						statusline = {},
						winbar = {},
					},
					ignore_focus = {},
					always_divide_middle = false, -- true | false
					globalstatus = false,
					refresh = {
						statusline = 1000,
						tabline = 1000,
						winbar = 1000,
					},
				},
				----------------                              ----------------

				-------------------    SECTION    ------------------------
				sections = {
					lualine_a = {
						{
							"mode",

							-- color = { fg = "#ffaa88", bg = "#000000", gui = "bold" }, -- Example: set text to orange, background to black, and style to bold
						},
						{ "filetype" },
						{
							"filename",
							file_status = true, -- displays file status (readonly status, modified status)
							path = 3, -- 0 | 1 | 2 | 3 | 4
							-- shorting_target = 20, -- Shortens path to leave 40 spaces in the window
						},
						{ "branch", "diff", "diagnostics" },
						{ "location" },
					},
					lualine_b = {},
					lualine_c = {},

					lualine_x = {},
					lualine_y = {},
					lualine_z = {},
				},
				----------------                              ----------------

				-------------------    INACTIVE SECTION    ------------------------
				inactive_sections = {
					lualine_a = {},
					lualine_b = {},
					lualine_c = { "filename" },
					lualine_x = { "location" },
					lualine_y = {},
					lualine_z = {},
				},
				----------------                              ----------------

				-------------------    TABLINE    ------------------------
				tabline = {
					lualine_a = {
						{
							"buffers",
							show_filename_only = false, -- Shows shortened relative path when set to false.
							hide_filename_extension = false, -- Hide filename extension when set to true.
							show_modified_status = true, -- Shows indicator when the buffer is modified.

							mode = 4, -- 0 | 1 | 2 | 3 | 4
							max_length = vim.o.columns * 2 / 3, -- Maximum width of buffers component,
							filetype_names = {
								TelescopePrompt = "Telescope",
								dashboard = "Dashboard",
								packer = "Packer",
								fzf = "FZF",
								alpha = "Alpha",
							}, -- Shows specific buffer name for that filetype ( { `filetype` = `buffer_name`, ... } )

							-- Automatically updates active buffer color to match color of other components (will be overidden if buffers_color is set)
							use_mode_colors = false,
							buffers_color = {
								active = "PmenuSel",
								inactive = "Pmenu",
							},

							symbols = {
								modified = " ●", -- Text to show when the buffer is modified
								alternate_file = "#", -- Text to show to identify the alternate file
								directory = "", -- Text to show when the buffer is a directory
							},
						},
					},
					-- lualine_b = { "branch", "diff", "diagnostics" },
					-- lualine_c = { "branch", "diff", "diagnostics" },

					-- lualine_x = { "tabs" },
					-- lualine_y = { "branch", "diff", "diagnostics" },
					-- lualine_z = { "branch", "diff", "diagnostics" },
				},

				-------------------    IDK     ------------------------
				winbar = {},
				inactive_winbar = {},
				extensions = {},
				----------------                              ----------------
			})
		end,
	},
}

----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
-- return {
-- 	"nvim-lualine/lualine.nvim",
-- 	dependencies = {
-- 		"nvim-tree/nvim-web-devicons",
-- 		"RRethy/base16-nvim", -- enhanches themes?
-- 	},
-- 	config = function()
--     -- stylua: ignore
--     local colors = {
--       blue   = '#80a0ff',
--       cyan   = '#79dac8',
--       black  = '#080808',
--       white  = '#c6c6c6',
--       red    = '#ff5189',
--       violet = '#d183e8',
--       grey   = '#303030',
--     }

-- 		local bubbles_theme = {
-- 			normal = {
-- 				a = { fg = colors.black, bg = colors.violet },
-- 				b = { fg = colors.white, bg = colors.grey },
-- 				c = { fg = colors.white },
-- 			},

-- 			insert = {
-- 				a = { fg = colors.black, bg = colors.blue },
-- 			},
-- 			visual = {
-- 				a = { fg = colors.black, bg = colors.cyan },
-- 			},
-- 			replace = {
-- 				a = { fg = colors.black, bg = colors.red },
-- 			},

-- 			inactive = {
-- 				a = { fg = colors.white, bg = colors.black },
-- 				b = { fg = colors.white, bg = colors.black },
-- 				c = { fg = colors.white },
-- 			},
-- 		}

-- 		require("lualine").setup({
-- 			options = {
-- 				theme = bubbles_theme,
-- 				component_separators = "",
-- 				section_separators = { left = "", right = "" },
-- 			},
-- 			sections = {
-- 				lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
-- 				lualine_b = { "filename", "branch" },
-- 				lualine_c = {
-- 					"%=", --[[ add your center compoentnts here in place of this comment ]]
-- 				},
-- 				lualine_x = {},
-- 				lualine_y = { "filetype", "progress" },
-- 				lualine_z = {
-- 					{ "location", separator = { right = "" }, left_padding = 2 },
-- 				},
-- 			},
-- 			inactive_sections = {
-- 				lualine_a = { "filename" },
-- 				lualine_b = {
-- 					{ "branch", "diff", "diagnostics" },
-- 				},
-- 				lualine_c = {},
-- 				lualine_x = {},
-- 				lualine_y = {},
-- 				lualine_z = { "location" },
-- 			},

-- 			tabline = {
-- 				lualine_a = {
-- 					{
-- 						"buffers",
-- 						show_filename_only = false, -- Shows shortened relative path when set to false.
-- 						hide_filename_extension = false, -- Hide filename extension when set to true.
-- 						show_modified_status = true, -- Shows indicator when the buffer is modified.

-- 						mode = 4, -- 0 | 1 | 2 | 3 | 4
-- 						max_length = vim.o.columns * 2 / 3, -- Maximum width of buffers component,
-- 						filetype_names = {
-- 							TelescopePrompt = "Telescope",
-- 							dashboard = "Dashboard",
-- 							packer = "Packer",
-- 							fzf = "FZF",
-- 							alpha = "Alpha",
-- 						},

-- 						symbols = {
-- 							modified = " ●", -- Text to show when the buffer is modified
-- 							alternate_file = "#", -- Text to show to identify the alternate file
-- 							directory = "", -- Text to show when the buffer is a directory
-- 						},
-- 					},
-- 					{
-- 						"filename",
-- 						file_status = true, -- displays file status (readonly status, modified status)
-- 						path = 3, -- 0 | 1 | 2 | 3 | 4
-- 						-- shorting_target = 20, -- Shortens path to leave 40 spaces in the window
-- 					},
-- 				},
-- 			},
-- 			extensions = {},
-- 		})
-- 	end,
-- }
