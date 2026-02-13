-- path: nvim/lua/plugins/editor/completion.lua
-- Description: blink.cmp — completion engine. Auto-show ON by default.
--              <leader>tc toggles completion on/off per-buffer via vim.b.completion
--              (blink.cmp's built-in mechanism, checked on every trigger event).
--              <C-Space> manually summons menu. <C-y> accepts. <C-n/p> navigates.
--              Sources: LSP + path + buffer. Snippets OFF.
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

	-- WHY no friendly-snippets: Snippets are OFF for Phase B. We validate completion
	-- in isolation before adding snippet complexity. Add in Phase E if wanted.
	-- dependencies = { "rafamadriz/friendly-snippets" },

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
  ---@diagnostic disable-next-line: undefined-doc-name
	---@type blink.cmp.Config
	opts = {
		-- ── Keymap ──────────────────────────────────────────────────────────
		-- WHY "default": C-y to accept (vim muscle memory), C-n/C-p to navigate,
		-- C-Space to toggle menu, C-e to dismiss. No Tab/S-Tab (avoids snippet
		-- navigation conflicts and feels cargo-culty on HHKB).
		--
		-- Default preset keybindings:
		--   <C-space>  show/toggle menu (MANUAL SUMMON — still works with auto-show ON)
		--   <C-y>      select_and_accept
		--   <C-n>      select next
		--   <C-p>      select prev
		--   <C-e>      hide/cancel
		--   <C-k>      toggle signature help (when signature.enabled = true)
		keymap = {
			preset = "default",
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

			-- WHY documentation auto_show = true: Once the menu IS open (auto or manual),
			-- show docs for the selected item immediately. No second keypress needed
			-- to read what a function does.
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 200, -- Small delay prevents flicker while navigating
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
			-- WHY no "snippets" source: Snippets are deferred. We validate LSP completion
			-- in isolation first. Snippet source can be added in Phase E.
			default = { "lsp", "path", "buffer" },

			-- WHY transform_items: Belt-and-suspenders snippet kill. Even with snippets
			-- removed from sources.default AND lua_ls callSnippet/keywordSnippet = "Disable",
			-- some LSPs can still send completion items with kind = Snippet through the
			-- LSP source. This catches them regardless of server-side behavior.
			-- Reference: cmp.saghen.dev/configuration/snippets
			--
			-- Uses vim.lsp.protocol (the LSP spec enum) instead of blink.cmp.types
			-- internal module — Snippet = 15 per LSP specification, never changes.
			transform_items = function(_, items)
				return vim.tbl_filter(function(item)
					return item.kind ~= vim.lsp.protocol.CompletionItemKind.Snippet
				end, items)
			end,
		},

		-- ── Signature Help ──────────────────────────────────────────────────
		-- WHY disabled: Opt-in later. Phase B validates completion only.
		-- When enabled, <C-k> toggles signature help (default preset).
		-- NOTE: Enabling this will collide with the <C-k> signature_help keymap
		-- in lsp.lua LspAttach. When flipping this switch, remove the LspAttach
		-- <C-k> binding and let blink.cmp own signature help (richer: tracks
		-- active parameter position).
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
