require("noice").setup({
	cmdline = {
		enabled = true, -- enables the Noice cmdline UI
		view = "cmdline_popup", -- view: `cmdline_popup` | `cmdline`
		opts = {},
		---@type table<string, CmdlineFormat>
		format = {
			cmdline = { pattern = "^:", icon = "", lang = "vim" },
			search_down = {
				view = "cmdline",
				kind = "search",
				pattern = "^/",
				icon = " ",
				lang = "regex",
			}, --  added view
			search_up = { view = "cmdline", kind = "search", pattern = "^%?", icon = " ", lang = "regex" }, --  added view
			filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
			lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
			help = { pattern = "^:%s*he?l?p?%s+", icon = "" },
			input = {}, -- Used by input()
			-- lua = false, -- to disable a format, set to `false`
		},
	},
	messages = {
		-- NOTE: If you enable messages, then the cmdline is enabled automatically.
		enabled = true, -- enables the Noice messages UI
		view = "notify", -- default view for messages
		view_error = "notify", -- view for errors
		view_warn = "notify", -- view for warnings
		view_history = "messages", -- view for :messages
		view_search = "virtualtext", -- view for search count messages. Set to `false` to disable -- ******* IMPORTANT THIS IS ANNOYING *******
	},
	popupmenu = {
		enabled = true,
		---@type 'nui'|'cmp'
		backend = "nui",
		---@type NoicePopupmenuItemKind|false
		kind_icons = {}, -- set to `false` to disable icons
	},
	---@type NoiceRouteConfig
	redirect = {
		enabled = true,
		view = "popup",
		filter = { event = "msg_show" },
	},
	---@type table<string, NoiceCommand>
	commands = {
		history = {
			-- options for the message history that you get with `:Noice`
			view = "split",
			opts = { enter = true, format = "details" },
			filter = {
				any = {
					{ event = "notify" },
					{ error = true },
					{ warning = true },
					{ event = "msg_show", kind = { "" } },
					{ event = "lsp", kind = "message" },
				},
			},
		},

		last = {
			view = "popup",
			opts = { enter = true, format = "details" },
			filter = {
				any = {
					{ event = "notify" },
					{ error = true },
					{ warning = true },
					{ event = "msg_show", kind = { "" } },
					{ event = "lsp", kind = "message" },
				},
			},
			filter_opts = { count = 1 },
		},
		errors = {
			view = "popup",
			opts = { enter = true, format = "details" },
			filter = { error = true },
			filter_opts = { reverse = true },
		},
	},
	notify = {
		enabled = true,
		view = "notify",
	},
	lsp = {
		progress = {
			enabled = true,
			--- @type NoiceFormat|string
			format = "lsp_progress",
			--- @type NoiceFormat|string
			format_done = "lsp_progress_done",
			throttle = 900, -- *** IMPORTANT ***
			view = "mini",
		},
		override = {
			["vim.lsp.util.convert_input_to_markdown_lines"] = true,
			["vim.lsp.util.stylize_markdown"] = true,
			["cmp.entry.get_documentation"] = true,
		},
		opts = {},
		signature = {
			enabled = true,
			auto_open = {
				enabled = true,
				trigger = true, -- Automatically show signature help when typing a trigger character from the LSP
				luasnip = true, -- Will open signature help when jumping to Luasnip insert nodes
				throttle = 50, -- Debounce lsp signature help request by 50ms
			},
			view = nil, -- when nil, use defaults from documentation
			---@type NoiceViewOptions
			opts = {}, -- merged with defaults from documentation
		},
		message = {
			-- Messages shown by lsp servers
			enabled = false,
			view = "notify",
			opts = {},
		},
		-- defaults for hover and signature help
		documentation = {
			view = "hover",
			---@type NoiceViewOptions
			opts = {
				lang = "markdown",
				replace = true,
				render = "plain",
				format = { "{message}" },
				win_options = { concealcursor = "n", conceallevel = 3 },
			},
		},
	},
	markdown = {
		enabled = true,
		hover = {
			["|(%S-)|"] = vim.cmd.help, -- vim help links
			["%[.-%]%((%S-)%)"] = require("noice.util").open, -- markdown links
		},
		highlights = {
			["|%S-|"] = "@text.reference",
			["@%S+"] = "@parameter",
			["^%s*(Parameters:)"] = "@text.title",
			["^%s*(Return:)"] = "@text.title",
			["^%s*(See also:)"] = "@text.title",
			["{%S-}"] = "@parameter",
		},
	},
	health = {
		checker = true, -- Disable if you don't want health checks to run
	},
	smart_move = {
		enabled = true, -- you can disable this behaviour here
		excluded_filetypes = { "cmp_menu", "cmp_docs", "notify" },
	},
	---@type NoicePresets
	presets = {
		bottom_search = false, -- use a classic bottom cmdline for search
		command_palette = false, -- position the cmdline and popupmenu together
		long_message_to_split = false, -- long messages will be sent to a split
		inc_rename = false, -- enables an input dialog for inc-rename.nvim
		lsp_doc_border = false, -- add a border to hover docs and signature help
	},
	throttle = 1000 / 30, -- how frequently does Noice need to check for ui updates? This has no effect when in blocking mode.

	---@type NoiceConfigViews
	views = {
		cmdline_popup = {
			position = {
				row = "14",
				col = "50%",
			},
			size = {
				width = "50%",
				height = "auto",
			},
			border = {
				style = rounded_border_style,
				-- style = "none",
			},
			filter_options = {},
			win_options = {
				winhighlight = { Normal = "TelescopePromptNormal", FloatBorder = "DiagnosticInfo" },
			},
		},
		split = {
			enter = true,
		},
		notify = {
			size = {
				width = 30,
			},
		},
		mini = {
			win_options = {
				winblend = 0,
				-- winhighlight = {}
			},
		},
		popupmenu = {
			relative = "editor",
			position = {
				row = 16,
				col = "50%",
			},
			size = {
				width = 55,
				height = 10,
			},
			border = {
				style = rounded_border_style,
				padding = { 0, 1 },
			},
			win_options = {
				winhighlight = { Normal = "TelescopePromptNormal", FloatBorder = "DiagnosticInfo" },
			},
		},
	},

	---@type NoiceRouteConfig[]
	routes = {
		{
			-- filter = {
			-- 	event = "msg_show",
			-- 	-- kind = "search_count",
			-- 	find = "written",
			-- },
			filter = {
				event = "lsp_progress_done",
			},
			opts = { skip = true },
		},
	}, --- @see section on routes

	---@type table<string, NoiceFilter>
	status = {}, --- @see section on statusline components

	---@type NoiceFormatOptions
	format = {}, --- @see section on formatting
})
