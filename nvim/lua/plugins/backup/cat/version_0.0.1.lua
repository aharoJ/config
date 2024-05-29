return {
	"catppuccin/nvim",
	lazy = false,
	name = "catppuccin",
	priority = 1000,
	config = function()
		require("catppuccin").setup({
			flavour = "mocha", -- latte, frappe, macchiato, mocha, auto
			background = { -- :h background
				light = "latte",
				dark = "mocha",
			},
			transparent_background = false, -- disables setting the background color.
			show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
			term_colors = false,
			dim_inactive = {
				enabled = false,
				shade = "dark",
				percentage = 0.15,
			},
			no_italic = false,
			no_bold = false,
			no_underline = false,
			styles = {
				comments = { "italic" },
				conditionals = { "italic" },
				loops = {},
				functions = {},
				keywords = {},
				strings = {},
				variables = {},
				numbers = {},
				booleans = {},
				properties = {},
				types = {},
				operators = {},
				-- miscs = {}, -- Uncomment to turn off hard-coded styles
			},
			color_overrides = {},
			highlight_overrides = {
				mocha = function(mocha)
					return {
--
["@keyword.import.java"] = { fg = "#6C7891" }, -- import
["@lsp.type.modifier.java"] = { fg = "#B0C8A9" }, -- public class 
["@lsp.typemod.class.declaration.java"] = { fg = "#C0CAF5" }, -- DECLARATION_CLASS 
-- ["@lsp.mod.declaration.java"] = { fg = "#C57F7F" }, -- DECLARATION_CLASS 
--
["@lsp.typemod.interface.public.java"] = { fg = "#8AA2A9" }, -- Map | Set | List
["@keyword.operator.java"] = { fg = "#7F88C5" },             -- new 
["@lsp.typemod.class.public.java"] = { fg = "#D1C8B0" }, -- HashMap | HashSet | ArrayList
-- ["@lsp.typemod.class.readonly.java"] = { fg = "#ffffff" }, -- <String, Integer>
-- ["@lsp.mod.public.java"] = { fg = "#ffffff" }, -- <String, Integer>
--
["@lsp.typemod.method.public.java"] = { fg = "#82A8DD" }, -- func name 
["@lsp.type.class.java"] = { fg = "#ffffff" }, -- PARAM Type Class
["@lsp.type.parameter.java"] = { fg = "#AA788D" }, -- PARAM var
--}
["@type.builtin.java"] = { fg = "#7E9C8C" }, -- int | double | float
["@keyword.conditional.java"] = { fg = "#7F88C5" }, -- if () else if ()
["@keyword.repeat.java"] = { fg = "#7F88C5" }, -- for 
["@keyword.return.java"] = { fg = "#7F88C5" },  -- RETURN
--
["@number.java"] = { fg = "#D1C8B0" }, -- 12345
["@number.float.java"] = { fg = "#D1C8B0" }, -- 0.3245 + double
["@constant.builtin.java"] = { fg = "#D1C8B0" }, -- null
["@boolean.java"] = { fg = "#D1C8B0" }, -- true | false
["@string.java"] = { fg = "#B0C8A9" }, -- true | false
-- ["@comment.java"] = { fg = "#FF7F50" }, -- comments //
-- ["@comment.documentation.java"] = { fg = "#FF7F50" }, -- /*    */
-- ffffff
-- ["@lsp.mod.declaration.java"] = { fg = "#DF5757" }, -- ****** LEAVE EMPTY ***
-- C0CAF5 |  | 6C7891 |  7E9C8C | 8AA2A9 | B8AD9E | A9C1B9 | B8AD9E | A9BEDA | B0C8A9 | F2B8D2 | B0A9C1
-- #C0CAF5: soft blue
-- #6C7891: soft indigo
-- #B8AD9E: darker yellow
-- #D1C8B0: nice brownish-yellow
-- #A9BEDA: fucking light blue
-- #7E9C8C: stronger green
-- #B0C8A9: lighter green
-- #F2B8D2: pink
-- #B0A9C1: gray
-- C57F9E pink
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
-- ["@"] = { fg = "#ffffff" },
					}
				end,
			},
			custom_highlights = {},
			integrations = {
				cmp = true,
				gitsigns = true,
				nvimtree = true,
				treesitter = true,
				notify = true,
				mini = {
					enabled = true,
					indentscope_color = "",
				},
				-- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
			},
		})

		-- setup must be called before loading
		vim.cmd.colorscheme("catppuccin")
	end,
}

-- ["@keyword.import.java"] = { fg = "#979BF1" }, -- import
-- ["@lsp.type.modifier.java"] = { fg = "#9CA3AF" }, -- public class
-- ["@keyword.conditional.java"] = { fg = "#F17C99" }, -- if () else if ()
-- ["@comment.java"] = { fg = "#F19797" }, -- comments //
-- ["@comment.documentation.java"] = { fg = "#FF7F50" }, -- /*    */
-- ["@keyword.operator.java"] = { fg = "#9CA3AF" }, -- new
-- ["@keyword.return.java"] = { fg = "#979BF1" },  -- RETURN
-- ["@lsp.typemod.class.declaration.java"] = { fg = "#4CA0B6" }, -- public class DECLARATION_NAME
-- ["@lsp.type.class.java"] = { fg = "#DF5757" }, -- Parameter Type Class
-- ["@lsp.mod.declaration.java"] = { fg = "#DF5757" }, -- ****** LEAVE EMPTY ***
-- ["@lsp.mod.public.java"] = { fg = "#ffffff" }, -- String
-- ["@type.builtin.java"] = { fg = "#ffffff" }, -- int | double | float
-- ["@lsp.typemod.class.typeArgument.java"] = { fg = "#DF5757" }, -- Map <String, Integer> -- class
-- ["@lsp.typemod.class.public.java"] = { fg = "#DF5757" }, -- HashMap | HashSet | ArrayList
-- ["@lsp.typemod.interface.public.java"] = { fg = "#DF5757" }, -- Map | Set | List
