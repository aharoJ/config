-- path: nvim/lua/plugins/core/colorscheme.lua
-- Description: Catppuccin Mocha. Loads first (lazy=false, priority=1000).
--              Integrations are ONLY listed for plugins that actually exist in this config.
-- CHANGELOG: 2026-02-03 | Removed dead integrations (cmp). Added mason, blink_cmp integrations
--            for Phase 2 editor stack. | ROLLBACK: Restore previous colorscheme.lua
return {
	"nvim-telescope/telescope.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local telescope = require("telescope")
		local builtin = require("telescope.builtin")
		local themes = require("telescope.themes")

		telescope.setup({
			defaults = {
				prompt_prefix = "  ",
				selection_caret = "  ",
				entry_prefix = "   ",
				sorting_strategy = "ascending",
				file_ignore_patterns = { "node_modules", ".git/" },
			},
		})

		-- ┌──────────────────────────────────────────────────────────────────┐
		-- │                                                                  │
		-- │   BODY — swap this table to see different layouts.               │
		-- │   Comment/uncomment ONE of the options below.                    │
		-- │                                                                  │
		-- └──────────────────────────────────────────────────────────────────┘

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 1: Horizontal (default — results left, preview right)
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- ┌─────────────────┐┌─────────────────┐
		-- │     Results      ││     Preview     │
		-- │                  ││                 │
		-- └─────────────────┘│                 │
		-- ┌─────────────────┐│                 │
		-- │     Prompt       ││                 │
		-- └─────────────────┘└─────────────────┘

		local find_files_opts = {
			layout_strategy = "horizontal",
			layout_config = {
				width = 0.8,
				height = 0.8,
				preview_width = 0.55,
				prompt_position = "bottom",
			},
		}

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 2: Horizontal — prompt on top, mirrored (preview left)
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- ┌─────────────────┐┌─────────────────┐
		-- │                  ││     Prompt      │
		-- │     Preview      │├─────────────────┤
		-- │                  ││     Results     │
		-- │                  ││                 │
		-- └─────────────────┘└─────────────────┘

		-- local find_files_opts = {
		--   layout_strategy = "horizontal",
		--   layout_config = {
		--     width = 0.85,
		--     height = 0.85,
		--     preview_width = 0.5,
		--     prompt_position = "top",
		--     mirror = true,
		--   },
		-- }

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 3: Vertical — stacked (preview top, results bottom)
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- ┌────────────────────────────┐
		-- │          Preview           │
		-- │                            │
		-- ├────────────────────────────┤
		-- │          Results           │
		-- │                            │
		-- ├────────────────────────────┤
		-- │          Prompt            │
		-- └────────────────────────────┘

		-- local find_files_opts = {
		--   layout_strategy = "vertical",
		--   layout_config = {
		--     width = 0.6,
		--     height = 0.9,
		--     preview_height = 0.5,
		--     prompt_position = "bottom",
		--     mirror = false,
		--   },
		-- }

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 4: Vertical mirrored — prompt top, results, then preview
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- ┌────────────────────────────┐
		-- │          Prompt            │
		-- ├────────────────────────────┤
		-- │          Results           │
		-- │                            │
		-- ├────────────────────────────┤
		-- │          Preview           │
		-- │                            │
		-- └────────────────────────────┘

		-- local find_files_opts = {
		--   layout_strategy = "vertical",
		--   layout_config = {
		--     width = 0.6,
		--     height = 0.9,
		--     preview_height = 0.45,
		--     prompt_position = "top",
		--     mirror = true,
		--   },
		-- }

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 5: Center / Dropdown — no preview, compact list
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		--        ┌──────────────────────┐
		--        │       Prompt         │
		--        ├──────────────────────┤
		--        │       Results        │
		--        │       Results        │
		--        │       Results        │
		--        └──────────────────────┘

		-- local find_files_opts = themes.get_dropdown({
		--   previewer = false,
		--   layout_config = {
		--     width = 0.5,
		--     height = 0.4,
		--   },
		-- })

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 6: Dropdown WITH preview below
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		--        ┌──────────────────────┐
		--        │       Prompt         │
		--        ├──────────────────────┤
		--        │       Results        │
		--        └──────────────────────┘
		--        ┌──────────────────────┐
		--        │       Preview        │
		--        └──────────────────────┘

		-- local find_files_opts = themes.get_dropdown({
		--   previewer = true,
		--   layout_config = {
		--     width = 0.6,
		--     height = 0.6,
		--   },
		-- })

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 7: Ivy — bottom panel, full width
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- ════════════════════════════════════════════
		-- │ Prompt                                   │
		-- ├────────────────────┬─────────────────────┤
		-- │ Results            │ Preview             │
		-- │                    │                     │
		-- ════════════════════════════════════════════

		-- local find_files_opts = themes.get_ivy({
		--   layout_config = {
		--     height = 0.4,
		--   },
		-- })

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 8: Ivy — no preview, ultra-minimal
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- ════════════════════════════════════════════
		-- │ Prompt                                   │
		-- ├──────────────────────────────────────────┤
		-- │ Results                                  │
		-- ════════════════════════════════════════════

		-- local find_files_opts = themes.get_ivy({
		--   previewer = false,
		--   layout_config = {
		--     height = 0.3,
		--   },
		-- })

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 9: Cursor — appears right at your cursor position
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		--   █ (cursor)
		--   ┌──────────────┐┌─────────────────┐
		--   │   Prompt     ││    Preview      │
		--   ├──────────────┤│                 │
		--   │   Results    ││                 │
		--   └──────────────┘└─────────────────┘

		-- local find_files_opts = themes.get_cursor({
		--   layout_config = {
		--     width = 0.7,
		--     height = 0.4,
		--   },
		-- })

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 10: Cursor — no preview, tiny popup at cursor
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		--   █ (cursor)
		--   ┌──────────────┐
		--   │   Prompt     │
		--   ├──────────────┤
		--   │   Results    │
		--   └──────────────┘

		-- local find_files_opts = themes.get_cursor({
		--   previewer = false,
		--   layout_config = {
		--     width = 0.4,
		--     height = 0.3,
		--   },
		-- })

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 11: Flex — auto-switches horizontal/vertical by window
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- (horizontal when wide, vertical when narrow)

		-- local find_files_opts = {
		--   layout_strategy = "flex",
		--   layout_config = {
		--     width = 0.8,
		--     height = 0.85,
		--     flip_columns = 130,
		--     horizontal = { preview_width = 0.55 },
		--     vertical = { preview_height = 0.45 },
		--   },
		-- }

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 12: Bottom pane — full-width bar at bottom
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- ┌──────────────────────────────────────────┐
		-- │                 (editor)                 │
		-- ├──────────┬───────────────────────────────┤
		-- │ Prompt   │ Preview                       │
		-- ├──────────┤                               │
		-- │ Results  │                               │
		-- └──────────┴───────────────────────────────┘

		-- local find_files_opts = {
		--   layout_strategy = "bottom_pane",
		--   layout_config = {
		--     height = 25,
		--     prompt_position = "top",
		--   },
		-- }

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 13: Horizontal wide — thin results, huge preview
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- ┌────────┐┌───────────────────────────────┐
		-- │Results ││          Preview              │
		-- │        ││                               │
		-- ├────────┤│                               │
		-- │Prompt  ││                               │
		-- └────────┘└───────────────────────────────┘

		-- local find_files_opts = {
		--   layout_strategy = "horizontal",
		--   layout_config = {
		--     width = 0.95,
		--     height = 0.85,
		--     preview_width = 0.7,
		--     prompt_position = "bottom",
		--   },
		-- }

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 14: Anchored top-right corner
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

		-- local find_files_opts = {
		--   layout_strategy = "horizontal",
		--   layout_config = {
		--     width = 0.6,
		--     height = 0.5,
		--     anchor = "NE",
		--     prompt_position = "top",
		--     preview_width = 0.5,
		--   },
		-- }

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 15: Full-screen vertical — max real estate
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

		-- local find_files_opts = {
		--   layout_strategy = "vertical",
		--   layout_config = {
		--     width = 0.99,
		--     height = 0.99,
		--     preview_height = 0.6,
		--     prompt_position = "top",
		--     mirror = true,
		--   },
		-- }

		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
		-- VARIATION 16: No preview, no borders — ultra minimal list
		-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

		-- local find_files_opts = {
		--   previewer = false,
		--   layout_strategy = "center",
		--   border = false,
		--   layout_config = {
		--     width = 0.4,
		--     height = 0.35,
		--   },
		-- }

		-- ┌──────────────────────────────────────────────────────────────────┐
		-- │                                                                  │
		-- │   SKELETON — keymap (don't touch)                                │
		-- │                                                                  │
		-- └──────────────────────────────────────────────────────────────────┘

		vim.keymap.set("n", "<leader>ff", function()
			builtin.find_files(find_files_opts)
		end, { desc = "Find Files" })
	end,
}
