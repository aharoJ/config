-- vim.opt.conceallevel = 2 -- Conceal markdown syntax -- BREAKS BACKTICKS
return {
	"epwalsh/obsidian.nvim",
	version = "*",
	lazy = true,
	ft = "markdown",
	dependencies = {
		"nvim-lua/plenary.nvim", -- required
		"epwalsh/pomo.nvim",
	},
	config = function()
		require("obsidian").setup({
			workspaces = {
				{
					name = "portfolio",
					path = "/Users/aharo/obsidian/portfolio",
				},
				{
					name = "dotfiles",
					path = "/Users/aharo/obsidian/dotfiles",
				},
				{
					name = "ems",
					path = "/Users/aharo/obsidian/ems",
				},
			},
			notes_subdir = "notes",
			log_level = vim.log.levels.INFO,

			daily_notes = {
				folder = "notes/dailies",
				date_format = "%Y-%m-%d",
				alias_format = "%B %-d, %Y",
				template = nil,
			},

			completion = {
				nvim_cmp = true,
				min_chars = 2,
			},

			mappings = {
				-- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
				["gv"] = {
					action = function()
						return require("obsidian").util.gf_passthrough()
					end,
					opts = { noremap = false, expr = true, buffer = true },
				},
				-- Toggle check-boxes.
				["<leader>ch"] = {
					action = function()
						return require("obsidian").util.toggle_checkbox()
					end,
					opts = { buffer = true },
				},
				-- Smart action depending on context, either follow link or toggle checkbox.
				["<cr>"] = {
					action = function()
						return require("obsidian").util.smart_action()
					end,
					opts = { buffer = true, expr = true },
				},
			},

			new_notes_location = "notes_subdir",

			-- Optional, customize how note IDs are generated given an optional title.
			---@param title string|?
			---@return string
			note_id_func = function(title)
				-- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
				-- In this case a note with the title 'My new note' will be given an ID that looks
				-- like '1657296016-my-new-note', and therefore the file name '1657296016-my-new-note.md'
				local suffix = ""
				if title ~= nil then
					-- If title is given, transform it into valid file name.
					suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
				else
					-- If title is nil, just add 4 random uppercase letters to the suffix.
					for _ = 1, 4 do
						suffix = suffix .. string.char(math.random(65, 90))
					end
				end
				return tostring(os.time()) .. "-" .. suffix
			end,

			-- Optional, customize how note file names are generated given the ID, target directory, and title.
			---@param spec { id: string, dir: obsidian.Path, title: string|? }
			---@return string|obsidian.Path The full path to the new note.
			note_path_func = function(spec)
				-- This is equivalent to the default behavior.
				local path = spec.dir / tostring(spec.id)
				return path:with_suffix(".md")
			end,

			wiki_link_func = function(opts)
				return require("obsidian.util").wiki_link_id_prefix(opts)
			end,

			-- Optional, customize how markdown links are formatted.
			markdown_link_func = function(opts)
				return require("obsidian.util").markdown_link(opts)
			end,

			-- Either 'wiki' or 'markdown'.
			preferred_link_style = "wiki",

			-- Optional, customize the default name or prefix when pasting images via `:ObsidianPasteImg`.
			---@return string
			image_name_func = function()
				-- Prefix image names with timestamp.
				return string.format("%s-", os.time())
			end,

			-- Optional, boolean or a function that takes a filename and returns a boolean.
			-- `true` indicates that you don't want obsidian.nvim to manage frontmatter.
			disable_frontmatter = false,

			-- Optional, alternatively you can customize the frontmatter data.
			---@return table
			note_frontmatter_func = function(note)
				-- Add the title of the note as an alias.
				if note.title then
					note:add_alias(note.title)
				end

				local out = { id = note.id, aliases = note.aliases, tags = note.tags }

				-- `note.metadata` contains any manually added fields in the frontmatter.
				-- So here we just make sure those fields are kept in the frontmatter.
				if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
					for k, v in pairs(note.metadata) do
						out[k] = v
					end
				end

				return out
			end,

			---@param url string
			follow_url_func = function(url)
				-- Open the URL in the default web browser.
				vim.fn.jobstart({ "open", url }) -- Mac OS
			end,

			-- Optional, set to true if you use the Obsidian Advanced URI plugin.
			-- https://github.com/Vinzent03/obsidian-advanced-uri
			use_advanced_uri = false,

			-- Optional, set to true to force ':ObsidianOpen' to bring the app to the foreground.
			open_app_foreground = false,

			picker = {
				name = "telescope.nvim",
				mappings = {
					new = "<C-x>", -- Create a new note from your query.
					insert_link = "<C-l>", -- Insert a link to the selected note.
				},
			},

			sort_by = "modified", -- ObsidianQuickSwitch: "path", "modified", "accessed", or "created"
			sort_reversed = true,
			open_notes_in = "current",

			-- Optional, configure additional syntax highlighting / extmarks.
			-- This requires you have `conceallevel` set to 1 or 2. See `:help conceallevel` for more details.
			ui = {
				enable = true, -- set to false to disable all additional syntax features
				update_debounce = 200, -- update delay after a text change (in milliseconds)
				-- Define how various check-boxes are displayed
				checkboxes = {
					-- NOTE: the 'char' value has to be a single character, and the highlight groups are defined below.
					[" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
					["x"] = { char = "", hl_group = "ObsidianDone" },
					[">"] = { char = "", hl_group = "ObsidianRightArrow" },
					["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
					-- Replace the above with this if you don't have a patched font:
					-- [" "] = { char = "☐", hl_group = "ObsidianTodo" },
					-- ["x"] = { char = "✔", hl_group = "ObsidianDone" },

					-- You can also add more custom ones...
				},
				-- Use bullet marks for non-checkbox lists.
				bullets = { char = "•", hl_group = "ObsidianBullet" },
				external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
				-- Replace the above with this if you don't have a patched font:
				-- external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
				reference_text = { hl_group = "ObsidianRefText" },
				highlight_text = { hl_group = "ObsidianHighlightText" },
				tags = { hl_group = "ObsidianTag" },
				block_ids = { hl_group = "ObsidianBlockID" },
				hl_groups = {
					-- The options are passed directly to `vim.api.nvim_set_hl()`. See `:help nvim_set_hl`.
					ObsidianTodo = { bold = true, fg = "#f78c6c" },
					ObsidianDone = { bold = true, fg = "#89ddff" },
					ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
					ObsidianTilde = { bold = true, fg = "#ff5370" },
					ObsidianBullet = { bold = true, fg = "#89ddff" },
					ObsidianRefText = { underline = true, fg = "#c792ea" },
					ObsidianExtLinkIcon = { fg = "#c792ea" },
					ObsidianTag = { italic = true, fg = "#89ddff" },
					ObsidianBlockID = { italic = true, fg = "#89ddff" },
					ObsidianHighlightText = { bg = "#75662e" },
				},
			},

			-- Specify how to handle attachments.
			attachments = {
				img_folder = "assets/imgs", -- This is the default
				---@param client obsidian.Client
				---@param path obsidian.Path the absolute path to the image file
				---@return string
				img_text_func = function(client, path)
					path = client:vault_relative_path(path) or path
					return string.format("![%s](%s)", path.name, path)
				end,
			},
		})
		-------------------       MAPS       ------------------------
		vim.api.nvim_set_keymap("n", "<leader>oo", "<cmd>ObsidianOpen<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>on", "<cmd>ObsidianNew<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>oq", "<cmd>ObsidianQuickSwitch<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>of", "<cmd>ObsidianFollowLink<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>ob", "<cmd>ObsidianBacklinks<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>ot", "<cmd>ObsidianTags<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>od", "<cmd>ObsidianToday<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>oy", "<cmd>ObsidianYesterday<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>om", "<cmd>ObsidianTomorrow<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>oi", "<cmd>ObsidianDailies<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>os", "<cmd>ObsidianSearch<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("v", "<leader>ol", "<cmd>ObsidianLink<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("v", "<leader>olk", "<cmd>ObsidianLinkNew<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>oe", "<cmd>ObsidianExtractNote<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>ov", "<cmd>ObsidianWorkspace<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>op", "<cmd>ObsidianPasteImg<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>or", "<cmd>ObsidianRename<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>ox", "<cmd>ObsidianToggleCheckbox<CR>", { noremap = true, silent = true })
		----------------                              ----------------
	end,
}

