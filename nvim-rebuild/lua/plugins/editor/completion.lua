-- path: nvim/lua/plugins/editor/completion.lua
-- Description: blink.cmp — batteries-included completion engine. Replaces nvim-cmp.
--              Sources: LSP, buffer, path, snippets (all built-in). Cmdline completion included.
--              Signature help built-in. Auto-brackets built-in. Uses native vim.snippet API.
-- CHANGELOG: 2026-02-03 | Initial Phase 2 build. blink.cmp v1.x with friendly-snippets.
--            | ROLLBACK: Delete file

return {
  "saghen/blink.cmp",
  version = "1.*",                    -- Use stable releases (pre-built binaries)
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = {
    "rafamadriz/friendly-snippets",   -- Community snippet collection (VS Code format)
  },

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- ── Keymap ──────────────────────────────────────────────────────────
    -- WHY "default": Uses C-y to accept (vim-native muscle memory), C-n/C-p to navigate,
    -- C-space to toggle menu, C-e to dismiss. No Tab/S-Tab completion (avoids conflicts
    -- with snippet navigation and feels cargo-culty).
    keymap = {
      preset = "default",
    },

    -- ── Appearance ──────────────────────────────────────────────────────
    appearance = {
      -- WHY mono: Nerd Font Mono ensures icons align properly in the completion menu.
      -- Font is configured in the terminal (Ghostty), not in Neovim.
      nerd_font_variant = "mono",
    },

    -- ── Completion Behavior ─────────────────────────────────────────────
    completion = {
      accept = {
        auto_brackets = {
          enabled = true,             -- Auto-insert brackets after function completions
        },
      },
      documentation = {
        auto_show = true,             -- Show docs automatically when item is selected
        auto_show_delay_ms = 200,     -- Brief delay to avoid flicker during fast scrolling
      },
      ghost_text = {
        enabled = false,              -- Disabled: too visually noisy. Use menu instead.
      },
      menu = {
        draw = {
          -- WHY treesitter: Renders completion items with treesitter highlighting.
          -- Makes LSP completions look like actual code, not plain text.
          treesitter = { "lsp" },
        },
      },
    },

    -- ── Snippets ────────────────────────────────────────────────────────
    -- WHY default preset: Uses native vim.snippet API (0.11+). No LuaSnip dependency.
    -- friendly-snippets provides VS Code format snippets, auto-loaded by blink.cmp.
    snippets = {
      preset = "default",
    },

    -- ── Sources ─────────────────────────────────────────────────────────
    -- WHY these four: LSP for intelligent completions, path for filesystem, snippets for
    -- templates, buffer for words in current file. All built-in to blink.cmp.
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },

    -- ── Cmdline Completion ──────────────────────────────────────────────
    -- WHY enabled: Completion in : command line and / search. Built-in to blink.cmp.
    cmdline = {
      enabled = true,
    },

    -- ── Signature Help ──────────────────────────────────────────────────
    -- WHY enabled: Shows function parameter hints as you type. Built-in, no plugin needed.
    signature = {
      enabled = true,
    },

    -- ── Fuzzy Matching ──────────────────────────────────────────────────
    -- WHY prefer_rust_with_warning: Uses the Rust SIMD fuzzy matcher for speed when available,
    -- falls back to Lua with a one-time warning if the binary isn't built. On M4 Max either
    -- engine is fast enough, but Rust handles large completion lists better.
    fuzzy = {
      implementation = "prefer_rust_with_warning",
    },
  },
}
