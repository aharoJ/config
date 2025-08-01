return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	dependencies = {
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make", cond = vim.fn.executable("make") == 1 },
		{ "nvim-telescope/telescope-ui-select.nvim" },
	},
	config = function()
		local ok, telescope = pcall(require, "telescope")
		if not ok then
			vim.notify("telescope.nvim not found!", vim.log.levels.ERROR)
			return
		end

		local actions = require("telescope.actions")
		local builtin = require("telescope.builtin")
		local themes = require("telescope.themes")

		---------------------------------------------------------------------
		-- THEMED WRAPPERS --------------------------------------------------
		---------------------------------------------------------------------
		local M = {}

		-- ░█▀▀░█░█░█▀▀░░░█▀▀░█▀█░█░█
		-- ░█░█░█▀█░█▀▀░░░█░░░█░█░█▀▄
		-- ░▀▀▀░▀░▀░▀▀▀░░░▀▀▀░▀░▀░▀░▀
		function M.files()
			builtin.find_files(themes.get_dropdown({
				prompt_title = "Files",
				layout_config = {
					width = 0.9,
					height = 0.3,
				},
				previewer = false,
				path_display = { "smart" }, -- or hidden | tail | absolute | relative | smart | shorten | truncate | filename_first
			}))
		end

		-- ░█░░░█▀█░█▄█░█▀█
		-- ░█░░░█▀█░█░█░█▀█
		-- ░▀▀▀░▀░▀░▀░▀░▀░▀
		function M.grep()
			builtin.live_grep({
				layout_strategy = "vertical", -- cursor | vertical | horizontal
				layout_config = {
					width = 0.5,
					height = 0.9,
					prompt_position = "top",
				},
			})
		end

		-- ░█▄▄░█░█░█▀▀░█▀█░█▀▀░█▀█
		-- ░█▄█░█▀█░█░█░█░█░█▀▀░█░█
		-- ░▀░▀░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀░▀
		function M.buffers()
			builtin.buffers(themes.get_dropdown({
				bufnr = 0, -- Current buffer only
				layout_strategy = "vertical", -- cursor | vertical | horizontal
				previewer = false, -- true | false
				initial_mode = "normal",
				-- 👇 hide the long path column & show the full message
				path_display = { "filename_first" }, -- or hidden | tail | absolute | relative | smart | shorten | truncate | filename_first
				line_width = "full",
				layout_config = {
					width = 0.9,
					height = 0.4,
					preview_height = 0.2,
					-- mirror = true,
					prompt_position = "top", -- Keep prompt at top but minimal
				},
				-- prompt_title = "Current Buffer Diagnostics",
				prompt_title = "", -- EMPTY STRING HIDES TITLE
				borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }, -- Clean border
				border = true,
			}))
		end

		-- ░█▀▄░█▀▀░█░█░▀█▀░█░█
		-- ░█▀▄░█▀▀░█░█░░█░░█▀█
		-- ░▀░▀░▀▀▀░▀▀▀░░▀░░▀░▀
		function M.git_status()
			builtin.git_status(themes.get_ivy({ layout_config = { height = 15 } }))
		end

		function M.treesitter_dropdown()
			builtin.treesitter(themes.get_dropdown({
				border = true,
				previewer = true, -- true | false
				shorten_path = false,
				layout_config = {
					width = 0.8,
					height = 0.7,
				},
			}))
		end

		-- ░█▀▀░█▀▄░█▀█░█▀▀░▀█▀░▄▀█░▀█▀░█▀█░█▀▀
		-- ░█▄▄░█▀▄░█▀█░▀▀█░░█░░█▀█░░█░░█░█░█▀▀
		-- ░▀░░░▀░▀░▀░▀░▀▀▀░░▀░░▀░▀░░▀░░▀░▀░▀▀▀
		function M.diagnostics_buffer()
			builtin.diagnostics({
				bufnr = 0, -- Current buffer only
				layout_strategy = "vertical", -- cursor | vertical | horizontal
				previewer = true, -- true | false
				initial_mode = "normal",
				layout_config = {
					width = 0.9,
					height = 0.7,
					preview_height = 0.4,
					preview_cutoff = 0,
					mirror = true,
					prompt_position = "bottom", -- Keep prompt at top but minimal
				},
				-- prompt_title = "Current Buffer Diagnostics",
				prompt_title = "", -- EMPTY STRING HIDES TITLE
				borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }, -- Clean border
				border = true,
			})
		end

		function M.diagnostics_workspace()
			builtin.diagnostics({
				layout_strategy = "vertical", -- cursor | vertical | horizontal
				previewer = true, -- true | false
				initial_mode = "normal",
				-- 👇 hide the long path column & show the full message
				path_display = { "hidden" }, -- hidden
				line_width = "full",
				layout_config = {
					width = 0.9,
					height = 0.7,
					preview_height = 0.4,
					-- preview_height = 0.2, -- CURSOR DONT EXIST
					-- preview_width = 0.3, -- VERTICAL DONT EXIST
					-- mirror = true, -- CURSOR DONT EXIST
					preview_cutoff = 0,
					mirror = true,
					prompt_position = "bottom",
				},
				-- prompt_title    = "Workspace Diagnostics",
				prompt_title = "", -- EMPTY STRING HIDES TITLE
				borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }, -- Clean border
				border = true,
			})
		end

		function M.commands()
			builtin.commands(themes.get_dropdown({
				previewer = false, -- true | false
				layout_config = { width = 0.5, height = 0.4 },
			}))
		end

		function M.keymaps()
			builtin.keymaps(themes.get_ivy({
				previewer = false, -- true | false
				layout_config = { width = 0.7, height = 0.5 },
			}))
		end

		function M.current_buffer_fuzzy_find()
			builtin.current_buffer_fuzzy_find(themes.get_dropdown({
				layout_strategy = "vertical", -- cursor | vertical | horizontal
				previewer = false, -- true | false
				-- 👇 hide the long path column & show the full message
				path_display = { "hidden" }, -- hidden
				line_width = "full",
				layout_config = {
					width = 0.9,
					height = 0.5,
				},
				prompt_title = "", -- EMPTY STRING HIDES TITLE
				borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
				border = true,
			}))
		end

		function M.project_fuzzy_find()
			-- live_grep → ripgrep over the entire cwd
			builtin.live_grep(themes.get_dropdown({
				cwd = vim.loop.cwd(), -- explicit for clarity
				layout_strategy = "vertical",
				previewer = false,
				path_display = { "hidden" },
				line_width = "full",
				layout_config = {
					width = 0.9,
					height = 0.6,
				},
				prompt_title = "", -- hide title
				borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
				border = true,
			}))
		end

		function M.spell_suggest()
			builtin.spell_suggest(themes.get_cursor({
				previewer = false, -- true | false
				layout_config = { width = 0.6, height = 0.3 },
			}))
		end

		function M.doc_symbols()
			builtin.lsp_document_symbols(themes.get_dropdown({
				prompt_title = "Doc Symbols",
				layout_strategy = "vertical", -- cursor | vertical | horizontal
				previewer = true, -- true | false
				initial_mode = "normal",
				layout_config = {
					width = 0.9,
					height = 0.7,
					preview_height = 0.4,
					preview_cutoff = 0,
					mirror = true,
					prompt_position = "bottom", -- Keep prompt at top but minimal
				},
				-- prompt_title = "Current Buffer Diagnostics",
				borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }, -- Clean border
				border = true,
			}))
		end

		---------------------------------------------------------------------
		-- CORE SETUP -------------------------------------------------------
		---------------------------------------------------------------------

		telescope.setup({
			defaults = {
				prompt_prefix = "> ",
				selection_caret = " ",
				winblend = 0,
				path_display = { "truncate" },

				mappings = {
					i = {
						["<C-j>"] = actions.move_selection_next,
						["<C-k>"] = actions.move_selection_previous,
						["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
					},
					n = { ["q"] = actions.close },
				},

				layout_strategy = "horizontal", -- cursor | vertical | horizontal
				layout_config = {
					horizontal = {
						prompt_position = "top",
						preview_width = 0.55,
						results_width = 0.45,
					},
					vertical = { mirror = false },
					width = 0.85,
					height = 0.85,
					-- preview_cutoff = 120,
					preview_cutoff = 0,
				},
			},

			pickers = {
				find_files = {
					theme = "dropdown",
					previewer = false, -- true | false
				},
				buffers = {
					theme = "cursor",
					previewer = false,
					initial_mode = "normal",
					sort_lastused = true,
					mappings = {
						-- n = { ["d"] = actions.delete_buffer },
					},
				},
				live_grep = {
					layout_strategy = "vertical", -- cursor | vertical | horizontal
				},
				git_status = { theme = "ivy" },
			},

			extensions = {
				["ui-select"] = {
					themes.get_dropdown({}),
				},
			},
		})

		----------------------------------------------------------------------
		-- EXTENSIONS --------------------------------------------------------
		----------------------------------------------------------------------
		pcall(telescope.load_extension, "fzf")
		pcall(telescope.load_extension, "ui-select")

		----------------------------------------------------------------------
		-- KEYMAPS -----------------------------------------------------------
		----------------------------------------------------------------------
		vim.keymap.set({ "n", "v" }, "gf", M.files, { desc = "[T] files" })
		vim.keymap.set("n", "<leader>fg", M.grep, { desc = "[T] live grep" })
		vim.keymap.set("n", "<leader>fb", M.buffers, { desc = "[T] buffers" })
		vim.keymap.set("n", "<leader>fG", M.git_status, { desc = "[T] git status" })
		vim.keymap.set("n", "<leader>ft", M.treesitter_dropdown, { desc = "[T] treesitter" }) -- deep

		vim.keymap.set("n", "<leader>gd", M.diagnostics_buffer, { desc = "[T] get diag" })
		vim.keymap.set("n", "<leader>gD", M.diagnostics_workspace, { desc = "[T] get project diag" })

		-- -------------------------------------------------
		vim.keymap.set("n", "<leader>fc", M.commands, { desc = "[T] commands" })
		vim.keymap.set("n", "<leader>fk", M.keymaps, { desc = "[T] keymaps" })
		vim.keymap.set("n", "<leader>fS", M.spell_suggest, { desc = "[T] spell suggest" })

		vim.keymap.set({ "n", "v" }, "ff", M.current_buffer_fuzzy_find, { desc = "[T] current buffer fuzzy find" })
		vim.keymap.set("n", "<leader>ff", M.project_fuzzy_find, { desc = "[T] current proj fuzzy find" })

		vim.keymap.set("n", "<leader>fs", M.doc_symbols, { desc = "[T] doc symbols" })

		return M
	end,
}
