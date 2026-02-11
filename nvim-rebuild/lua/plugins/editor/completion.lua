-- path: nvim/lua/plugins/editor/completion.lua
-- Description: blink.cmp — completion engine. Manual-only trigger (<C-Space>).
--              Sources: LSP + path + buffer. Snippets OFF. No auto-completion.
--              Capabilities auto-wired to LSP servers via blink.cmp's plugin/blink-cmp.lua
--              (Neovim 0.11+ vim.lsp.config integration — no manual wiring needed).
-- CHANGELOG: 2026-02-11 | Phase B build. Manual trigger, no snippets, Lua-only validation.
--            Added transform_items snippet filter (belt-and-suspenders with lua_ls
--            callSnippet/keywordSnippet = "Disable"). Stolen from ChatGPT feedback.
--            | ROLLBACK: Delete file, remove blink.cmp dependency from lsp.lua

return {
  "saghen/blink.cmp",
  version = "1.*",                    -- Stable releases with pre-built fuzzy binary (M4 Max: aarch64-apple-darwin)

  -- WHY these events: InsertEnter is the primary trigger for completion.
  -- CmdlineEnter enables cmdline completion (: and / modes).
  event = { "InsertEnter", "CmdlineEnter" },

  -- WHY no friendly-snippets: Snippets are OFF for Phase B. We validate completion
  -- in isolation before adding snippet complexity. Add in Phase E if wanted.
  -- dependencies = { "rafamadriz/friendly-snippets" },

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {

    -- ── Keymap ──────────────────────────────────────────────────────────
    -- WHY "default": C-y to accept (vim muscle memory), C-n/C-p to navigate,
    -- C-Space to toggle menu, C-e to dismiss. No Tab/S-Tab (avoids snippet
    -- navigation conflicts and feels cargo-culty on HHKB).
    --
    -- Default preset keybindings:
    --   <C-space>  show/toggle menu (THIS IS OUR MANUAL TRIGGER)
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

      -- WHY auto_show = false: MANUAL-ONLY completion. The menu appears ONLY
      -- when you press <C-Space>. No popups while typing. This is the core
      -- IDEI principle — you summon intelligence, it doesn't interrupt you.
      menu = {
        auto_show = false,
      },

      -- WHY documentation auto_show = true: Once the menu IS open (manually),
      -- show docs for the selected item immediately. No second keypress needed
      -- to read what a function does.
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,     -- Small delay prevents flicker while navigating
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

      -- WHY ghost_text disabled: Ghost text is visual noise when completion is
      -- manual-only. It defeats the purpose of summoning on demand.
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
      -- Stolen from ChatGPT feedback audit. Reference: cmp.saghen.dev/configuration/snippets
      transform_items = function(_, items)
        return vim.tbl_filter(function(item)
          return item.kind ~= require("blink.cmp.types").CompletionItemKind.Snippet
        end, items)
      end,
    },

    -- ── Signature Help ──────────────────────────────────────────────────
    -- WHY disabled: Opt-in later. Phase B validates completion only.
    -- When enabled, <C-k> toggles signature help (default preset).
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
