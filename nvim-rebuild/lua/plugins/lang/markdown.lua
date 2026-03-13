-- path: nvim/lua/plugins/lang/markdown.lua
-- Description: render-markdown.nvim — Treesitter-powered Markdown beautification.
--              Conceal-based rendering: raw syntax (# ``` - [ ] ---) replaced with
--              styled visuals. Cursor line reveals raw syntax for editing. Minimal
--              config — defaults are excellent, only overriding what earns its place.
-- CHANGELOG: 2026-03-10 | Created. Minimal overrides on top of sane defaults.
--            sign disabled (visual noise), round table borders, latex off (unused),
--            completions LSP enabled (free callout/checkbox completions via blink.cmp),
--            <leader>tm toggle.
--            | ROLLBACK: Delete file. Remove conceallevel from after/ftplugin/markdown.lua.

return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = { "markdown" },
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	cmd = { "RenderMarkdown" },
	keys = {
		{
			"<leader>tm",
			function()
				require("render-markdown").buf_toggle()
			end,
			mode = "n",
			desc = "[toggle] markdown render",
		},
	},
	---@module 'render-markdown'
	---@type render.md.UserConfig
	opts = {
		-- ── Completions ───────────────────────────────────────────────────
		-- WHY: Free callout + checkbox completions via blink.cmp's LSP source.
		-- In-process LSP — no external server, zero config beyond this flag.
		completions = {
			lsp = { enabled = true },
		},

		-- ── Sign Column ──────────────────────────────────────────────────
		-- WHY disabled: Heading/code sign icons add visual clutter alongside
		-- LSP diagnostics and git signs. The in-buffer rendering is enough.
		sign = { enabled = false },

		-- ── Headings ─────────────────────────────────────────────────────
		-- WHY: Defaults are already clean (numbered icons, full-width background,
		-- overlay position). Only overriding icons to simpler glyphs — the
		-- numbered subscript icons (󰲡 󰲣 ...) are noisy for quick notes.
		heading = {
			icons = { "(1) ", "(2) ", "(3) ", "(4) ", "(5) ", "(6) " },
			-- icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
		},

		-- ── Bullets ──────────────────────────────────────────────────────
		-- WHY: Default ● ○ ◆ ◇ are heavy. Single dash repeats at all levels.
		bullet = {
			icons = { "•" },
		},

		-- ── Code Blocks ──────────────────────────────────────────────────
		-- WHY border = "thin": Subtle ▄/▀ borders above and below code blocks.
		-- Default "hide" conceals ``` lines entirely which can feel disorienting
		-- when you have many back-to-back code blocks (like your deployment notes).
		-- "thin" gives a clean visual boundary without being heavy.
		code = {
			border = "thin",
		},

		-- ── Tables ───────────────────────────────────────────────────────
		-- WHY round: Rounded corners (╭╮╰╯) instead of sharp (┌┐└┘).
		-- Softer aesthetic, matches the rounded borders on floating windows.
		pipe_table = {
			preset = "round",
		},

		-- ── Latex ────────────────────────────────────────────────────────
		-- WHY disabled: Not part of the stack. No pylatexenc, no utftex.
		-- Avoids :checkhealth warnings about missing converters.
		latex = { enabled = false },

		-- ── Win Options ──────────────────────────────────────────────────
		-- WHY: Plugin manages conceallevel automatically — sets rendered = 3
		-- (fully hidden) when rendering, restores default when not. Belt-and-
		-- suspenders with the conceallevel in after/ftplugin/markdown.lua.
		win_options = {
			conceallevel = {
				default = vim.api.nvim_get_option_value("conceallevel", {}),
				rendered = 3,
			},
			concealcursor = {
				default = vim.api.nvim_get_option_value("concealcursor", {}),
				rendered = "",
			},
		},
	},
}
