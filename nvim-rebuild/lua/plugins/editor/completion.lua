-- path: nvim/lua/plugins/editor/completion.lua
-- Description: blink.cmp — completion engine. Auto-show ON by default.
--              <leader>tc toggles completion on/off per-buffer via vim.b.completion
--              (blink.cmp's built-in mechanism, checked on every trigger event).
--              <C-Space> manually summons menu. <C-y> accepts. <C-n/p> navigates.
--              <C-l> / <C-k> jump forward/backward through snippet placeholders.
--              Sources: LSP + path + buffer + snippets. friendly-snippets collection.
--              Capabilities auto-wired to LSP servers via blink.cmp's plugin/blink-cmp.lua
--              (Neovim 0.11+ vim.lsp.config integration — no manual wiring needed).
-- CHANGELOG: 2026-02-11 | Phase B build. Manual trigger, no snippets, Lua-only validation.
--            Added transform_items snippet filter (belt-and-suspenders with lua_ls
--            callSnippet/keywordSnippet = "Disable"). Stolen from ChatGPT feedback.
--            | ROLLBACK: Delete file, remove blink.cmp dependency from lsp.lua
--            2026-02-12 | Deep dive cleanup. Switched transform_items from
--            blink.cmp.types internal import to vim.lsp.protocol (LSP spec enum,
--            never changes, zero external dependency). Added event field clarification
--            comment (dependency chain preempts these events in practice).
--            | ROLLBACK: Revert transform_items to require("blink.cmp.types"), remove comment
--            2026-02-13 | Switched from manual-only (auto_show = false) to auto-show
--            ON by default. Added <leader>tc toggle via vim.b.completion — blink.cmp's
--            built-in buffer-local kill switch, checked on every trigger event. When
--            toggled off: keymaps, auto-show, manual <C-Space>, and signature help
--            are ALL disabled for the current buffer. vim.notify confirms state.
--            Removed auto_show = false from menu config. Kept <C-Space> as manual
--            summon (still works when completion is enabled).
--            | ROLLBACK: Set completion.menu.auto_show = false, remove <leader>tc
--            key entry, remove toggle comment block
--            2026-02-13 | SNIPPETS ENABLED. Added friendly-snippets dependency,
--            "snippets" to sources.default, <C-l>/<C-k> snippet navigation keymaps.
--            Snippets ranked below LSP items (score_offset = -3). Removed
--            transform_items snippet filter. show_in_snippet = false prevents
--            auto-show from firing inside snippet placeholders. lua_ls snippet
--            kill switches reversed in lsp/lua_ls.lua (callSnippet/keywordSnippet
--            = "Replace").
--            | ROLLBACK: Remove friendly-snippets dep, remove "snippets" from
--            sources.default, remove <C-l>/<C-k> keymaps, restore transform_items
--            filter, remove show_in_snippet, remove providers.snippets config.
--            Revert lua_ls.lua callSnippet/keywordSnippet to "Disable".

return {
	"saghen/blink.cmp",
	version = "1.*", -- Stable releases with pre-built fuzzy binary (M4 Max: aarch64-apple-darwin)

	-- WHY these events: InsertEnter is the primary trigger for completion.
	-- CmdlineEnter enables cmdline completion (: and / modes).
	-- NOTE: In practice, blink.cmp loads earlier than these events because lsp.lua
	-- lists it as a mason-lspconfig dependency (which loads on BufReadPre). These
	-- events serve as a fallback and document intent — if the dependency chain ever
	-- changes, blink.cmp still loads at the right time.
	event = { "InsertEnter", "CmdlineEnter" },

	-- WHY friendly-snippets: Community-maintained snippet collection covering 30+
	-- languages. Provides the actual snippet definitions that blink.cmp's built-in
	-- snippets source expands via vim.snippet (native 0.11+ API).
	dependencies = { "rafamadriz/friendly-snippets" },

	keys = {
		-- WHY <leader>tc: Toggle completion per-buffer. Uses vim.b.completion — blink.cmp's
		-- built-in buffer-local mechanism. Default enabled state: vim.b.completion = nil,
		-- which blink treats as enabled (default condition: vim.b.completion ~= false).
		-- Toggling sets it to false (disabled) or nil (re-enabled, back to default).
		-- This is a FULL kill switch: keymaps, auto-show, manual <C-Space>, signature
		-- help — ALL disabled when off. Not just "quiet mode."
		{
			"<leader>tc",
			function()
				-- WHY nil not true: blink's default condition is `vim.b.completion ~= false`.
				-- nil satisfies that check. Setting to true would override even the buftype
				-- prompt guard (blink docs: "default conditions are ignored when explicitly
				-- set to true"). nil preserves all default safety checks.
				if vim.b.completion == false then
					vim.b.completion = nil
					vim.notify("Completion ON", vim.log.levels.INFO)
				else
					require("blink.cmp").hide()
					vim.b.completion = false
					vim.notify("Completion OFF", vim.log.levels.INFO)
				end
			end,
			mode = "n",
			desc = "[toggle] completion (buffer-local)",
		},
	},

	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {

		-- ── Keymap ──────────────────────────────────────────────────────────
		-- WHY "default" + overrides: Keeps C-y/C-n/C-p/C-Space/C-e from the
		-- default preset. Adds <C-l>/<C-k> for snippet placeholder navigation.
		--
		-- Default preset keybindings (inherited):
		--   <C-space>  show/toggle menu (MANUAL SUMMON — still works with auto-show ON)
		--   <C-y>      select_and_accept
		--   <C-n>      select next
		--   <C-p>      select prev
		--   <C-e>      hide/cancel
		--
		-- Custom overrides:
		--   <C-l>      snippet_forward (jump to next placeholder) → fallback
		--   <C-k>      snippet_backward (jump to prev placeholder) → fallback
		--
		-- WHY <C-l> forward: Home row, vim l = right/forward metaphor. No meaningful
		-- insert-mode loss (default <C-l> redraws screen — rarely used in insert).
		--
		-- WHY <C-k> backward: Home row, k = up/prev in vim. Loses digraph input
		-- (which you almost certainly don't use). Overrides blink's default <C-k>
		-- signature help toggle — signature help is disabled anyway.
		--
		-- WHY NOT <C-h>: Loses backspace in insert mode — genuinely annoying.
		-- WHY NOT <C-j>: Loses newline in insert mode — could bite you.
		-- WHY NOT Tab/S-Tab: Feels cargo-culty on HHKB. Keeps Tab for indentation.
		keymap = {
			preset = "default",
			["<C-l>"] = { "snippet_forward", "fallback" },
			["<C-k>"] = { "snippet_backward", "fallback" },
		},

		-- ── Appearance ──────────────────────────────────────────────────────
		appearance = {
			-- WHY mono: Nerd Font Mono ensures icons align properly in completion menu.
			-- Font itself is configured in Ghostty, not Neovim.
			nerd_font_variant = "mono",
		},

		-- ── Completion ──────────────────────────────────────────────────────
		completion = {

			-- WHY auto_show defaults (not set): blink.cmp defaults auto_show = true.
			-- Completion menu appears as you type. <C-Space> still works as a manual
			-- summon. <leader>tc toggles the entire completion system off per-buffer
			-- via vim.b.completion when you want silence.
			menu = {},

			-- WHY show_in_snippet = false: When you're inside a snippet placeholder,
			-- the auto-show completion menu is suppressed. This prevents the menu from
			-- popping up and interfering with snippet navigation (<C-l>/<C-k>).
			-- You can still summon completion inside a snippet with <C-Space> if needed.
			trigger = {
				show_in_snippet = false,
			},

			-- WHY documentation auto_show = true: Once the menu IS open (auto or manual),
			-- show docs for the selected item immediately. No second keypress needed
			-- to read what a function does.
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 200, -- Small delay prevents flicker while navigating
				window = {
					max_width = 60, -- characters wide (default is ~60)
					max_height = 12, -- lines tall (default is ~10-12)
				},
			},

			-- WHY preselect = true, auto_insert = false: First item is highlighted
			-- (so C-y accepts it immediately) but nothing is inserted into the buffer
			-- until you explicitly accept. No phantom text while browsing.
			list = {
				selection = {
					preselect = true,
					auto_insert = false,
				},
			},

			-- WHY ghost_text disabled: Ghost text is visual noise alongside auto-show.
			-- The menu already shows suggestions — ghost text would be redundant.
			ghost_text = {
				enabled = false,
			},

			-- WHY auto_brackets enabled: When accepting a function completion, auto-insert
			-- parentheses. This is genuine convenience, not automation — you chose to accept.
			accept = {
				auto_brackets = {
					enabled = true,
				},
			},
		},

		-- ── Sources ─────────────────────────────────────────────────────────
		sources = {
			-- WHY "snippets" added: friendly-snippets provides 30+ language snippet
			-- collections. blink.cmp's built-in snippets source expands them via
			-- vim.snippet (native 0.11+ API). No LuaSnip dependency needed.
			default = { "lsp", "path", "buffer", "snippets" },

			-- WHY providers config: Lower snippet priority so LSP completions always
			-- rank above snippets. Prevents snippet noise from drowning out LSP items
			-- when typing function names or variable references.
			providers = {
				snippets = {
					score_offset = -3, -- Rank below LSP (0) and path items
				},
			},
		},

		-- ── Signature Help ──────────────────────────────────────────────────
		-- WHY disabled: Opt-in later. Phase B validates completion only.
		-- When enabled, use a dedicated keymap (not <C-k>, which is now snippet_backward).
		-- NOTE: If enabling, add a new keymap for show_signature (e.g. <C-S> to match
		-- Neovim 0.11's built-in insert-mode signature help default).
		signature = {
			enabled = false,
		},

		-- ── Cmdline ─────────────────────────────────────────────────────────
		-- WHY: Cmdline completion is useful for :commands and /search.
		-- blink.cmp handles this natively — no separate plugin needed.
		-- auto_show defaults to false for cmdline, true for cmdwin. We keep defaults.
		cmdline = {},

		-- ── Fuzzy ───────────────────────────────────────────────────────────
		-- WHY prefer_rust_with_warning: Rust SIMD matcher is ~6x faster than Lua.
		-- On M4 Max with pre-built aarch64-apple-darwin binary, this is free performance.
		-- Falls back to Lua if binary unavailable (with a warning).
		fuzzy = {
			implementation = "prefer_rust_with_warning",
		},
	},
}
