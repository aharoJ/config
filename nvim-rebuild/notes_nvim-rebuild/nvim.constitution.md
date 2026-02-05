# NEOVIM CONFIGURATION CONSTITUTION (v2.4)

## PREAMBLE — READ THIS FIRST, OBEY IT ALWAYS

This constitution governs all work on my Neovim configuration. Every file you generate, every keybinding you suggest, every architectural decision you make — must comply with this document. No exceptions. No "I thought it would be better if..." deviations.

I am building a **Personalized Development Environment (PDE)** — not a distro, not a clone of LazyVim, not a "starter kit." This is MY editor, shaped by MY philosophy, optimized for MY hardware and workflow. The goal is a configuration so clean and intentional that every line earns its place.

**Quality Bar:** Top 0.1% craftsmanship. Zero tolerance for cargo-culting. Every configuration decision must be **grep-able**, **self-documenting**, and **immediately comprehensible** to a future self at 3 AM during an incident.

---

## ARTICLE I — IDENTITY & HARDWARE CONTEXT

### Who I Am

- Sole architect and engineer on a production system (580+ users)
- Stack: Spring Boot, React/Next.js, PostgreSQL, TypeScript, Java, Lua
- Philosophy: Elegant simplicity. Staff-engineer quality. Explicit over abstract. No DRY worship.
- Natural philosopher — I absorb patterns from the best, then forge my own path

### Hardware & Toolchain

| Component          | Detail                                                       |
| ------------------ | ------------------------------------------------------------ |
| **Machine**        | Apple Silicon M4 Max, macOS 26.2 (Tahoe, build 25C56)        |
| **Keyboard**       | HHKB Professional Hybrid Type-S (60% layout, topre switches) |
| **Key Remapper**   | Karabiner-Elements (keyboard firmware in software)           |
| **Terminal**       | Ghostty (GPU-accelerated, Zig-based, v1.2+)                  |
| **Multiplexer**    | tmux (terminal sessions, panes, persistence)                 |
| **Shell**          | Fish shell (via Homebrew)                                    |
| **Prompt**         | Starship (cross-shell, minimal config)                       |
| **Window Manager** | yabai + skhd (OS-level tiling & hotkeys)                     |
| **File Manager**   | yazi (terminal file manager, Rust-based)                     |
| **ls Replacement** | eza (modern ls with git integration)                         |
| **Neovim**         | v0.11.x stable (target v0.12 compatibility when it drops)    |
| **Plugin Manager** | lazy.nvim (latest stable branch)                             |
| **Font**           | Nerd Font patched (configured in terminal, NOT in Neovim)    |

### The Two Spatial Layers — tmux & yabai Are Parallel, Not Competing

The PDE has two distinct spatial management systems that operate in parallel:

**yabai + skhd** = OS-level window tiling. Manages macOS windows: Ghostty, browser, Slack, Finder. skhd provides system-wide hotkeys. This is the **macro** spatial layer — which application is where on which space/display.

**tmux** = Terminal multiplexer. Manages sessions, windows, and panes INSIDE Ghostty. Provides session persistence (detach/reattach), named workspaces per project, and pane splitting within the terminal. This is the **micro** spatial layer — what's happening inside the terminal.

**Neovim** = The innermost layer. Manages splits and buffers inside a single tmux pane. Neovim does NOT need to be a terminal multiplexer — tmux handles that.

```
┌─── macOS Desktop (yabai) ────────────────────────────────┐
│  ┌─── Ghostty Window ─────────────────────────────────┐  │
│  │  ┌─── tmux session: "webapp" ───────────────────┐  │  │
│  │  │  ┌─── tmux pane ─────┐ ┌─── tmux pane ────┐ │  │  │
│  │  │  │                   │ │                   │ │  │  │
│  │  │  │  Neovim           │ │  shell / lazygit  │ │  │  │
│  │  │  │  (splits/buffers) │ │  / test runner    │ │  │  │
│  │  │  │                   │ │                   │ │  │  │
│  │  │  └───────────────────┘ └───────────────────┘ │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌─── Browser Window ──┐ ┌─── Slack Window ──────────┐  │
│  │                      │ │                           │  │
│  └──────────────────────┘ └───────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

**What this means for Neovim:**

- Neovim does NOT need a terminal plugin for running shells — tmux panes handle that
- `<C-hjkl>` navigation must be seamless across Neovim splits AND tmux panes (vim-tmux-navigator or equivalent)
- Neovim's built-in `:terminal` is still useful for quick one-off commands, but tmux is the persistent terminal layer
- Session management is tmux's job, not Neovim's (no session plugins needed)

### HHKB-Specific Considerations

- **Ctrl** is at home row left (where CapsLock normally is) — Ctrl-based bindings are ERGONOMIC, not painful
- **Meta/Alt** is thumb-accessible on HHKB — `<M->` bindings are a prime keybinding dimension, use aggressively
- **No dedicated arrow keys** — all navigation is vim-native (hjkl) or Fn-layer. NEVER create bindings that depend on arrow keys for frequent actions
- **No F-row without Fn** — avoid bindings that rely on F1-F12 for frequent actions
- **Escape is top-left**, already accessible — no need for jk/jj escape mappings
- Compact 60-key layout — every finger movement matters, minimize reach
- Fn+[/;/'/] are arrow keys on HHKB — avoid conflicts with these combos

### Karabiner-Elements Role

Karabiner sits BELOW everything else — it transforms physical key events before any application sees them. Potential uses:

- Hyper key (Caps Lock → Cmd+Ctrl+Opt+Shift simultaneously) for system-wide shortcuts
- Layer keys for custom keyboard layers
- HHKB-specific remapping if needed beyond the board's built-in DIP switches

**Rule:** Karabiner config is defined AFTER Neovim + tmux + skhd keybindings are settled. It resolves conflicts and adds capabilities that individual tools can't provide. It does NOT create dependencies — if Karabiner is disabled, Neovim and tmux must still work correctly with native keys.

### Ecosystem Context (Everything Is Being Rebuilt)

The following tools exist in the broader dotfiles ecosystem. ALL of them are being nuked and rebuilt from scratch — Neovim is the FIRST config being written. Do NOT design Neovim around any external tool's current or assumed configuration. Neovim stands alone.

**The full toolchain (rebuild order):**

```
1. Karabiner-Elements   ← keyboard layer (resolves conflicts, built last but lowest in stack)
2. Neovim core/         ← the brain (defines the keybinding language for the inner layer)
3. Ghostty              ← the glass (GPU rendering, true color, key passthrough to tmux/nvim)
4. tmux                 ← the multiplexer (sessions, panes, persistence inside the terminal)
5. yabai + skhd         ← the tiler (OS-level window management, parallel to tmux)
6. Fish + Starship      ← the shell (fast, minimal config surface)
7. yazi                 ← the navigator (terminal file manager, complements nvim explorer)
8. eza                  ← tiny utility (ls replacement, last priority)
9. Neovim plugins       ← surgical additions (only after core is rock-solid)
```

**What this means for Neovim config:**

- Use universally correct settings (`termguicolors`, clipboard, etc.) — not tool-specific workarounds
- Be AWARE of the keybinding namespaces tmux and skhd will claim (see Article VI) but don't reserve them preemptively — Neovim defines its own bindings first, then tmux/skhd adapt
- Don't assume any specific shell, terminal, or WM behavior
- Font rendering is handled by Ghostty — Neovim does NOT set fonts
- If a Neovim setting needs a shell path, use the system default or ask — don't hardcode
- tmux will be configured to pass through keys Neovim needs (especially `<C-hjkl>`, `<Esc>`)

---

## ARTICLE II — NEOVIM VERSION AWARENESS (0.11+ / 0.12 HEAD)

You MUST be aware of these Neovim 0.11+ features and use them where appropriate. Do NOT install plugins that duplicate built-in functionality.

### Native LSP (0.11+) — The Modern Way

- LSP client is fully built-in via `vim.lsp`
- **Server configs go in `~/.config/nvim/lsp/<server_name>.lua`** — file-based discovery, auto-loaded by `vim.lsp.config()`
- Servers are enabled with `vim.lsp.enable({ "lua_ls", "ts_ls", "rust_analyzer" })` — no nvim-lspconfig boilerplate needed
- Built-in auto-completion is available via `vim.lsp.completion.enable(true, client_id, bufnr, { autotrigger = true })`
- LspAttach autocommand for keymaps — do NOT define LSP keymaps in `core/keymaps.lua`
- Default LSP keymaps in 0.11+: `grn` (rename), `gra` (code action), `grr` (references), `gri` (implementations), `gO` (document symbols)
- `:checkhealth lsp` for diagnostics
- **NOTE:** LSP/completion/diagnostics are DEPRIORITIZED — leave existing working config as-is, do not refactor until explicitly asked. But the architecture MUST encode the correct 0.11+ pattern for when we get there.

### Native LSP Config Pattern (0.11+)

```lua
-- ~/.config/nvim/lsp/lua_ls.lua (auto-discovered by vim.lsp.config)
return {
  settings = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
      diagnostics = { globals = { "vim" } },
    },
  },
}

-- ~/.config/nvim/lsp/ts_ls.lua
return {
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
  end,
}

-- Then enable in core/ or an autocmd:
-- vim.lsp.enable({ "lua_ls", "ts_ls" })
```

### Built-in Diagnostics (0.11+)

- `vim.diagnostic.config()` is the native API
- Virtual text is now OPT-IN (disabled by default in 0.11) — must explicitly enable if wanted
- `virtual_lines` diagnostic handler is built-in (inspired by lsp_lines.nvim) — `virtual_lines = { current_line = true }` for clean display
- `current_line` option for virtual text shows diagnostics only on cursor line
- Diagnostic signs can NO LONGER use legacy `:sign-define` (use `vim.diagnostic.config` signs table)

### Treesitter (0.11+)

- Async parsing — no more UI blocking on large files
- Non-blocking injection queries
- Async folding — `vim.treesitter.foldexpr()` is production-ready
- Significant performance improvements for large codebases
- On M4 Max: enable for ALL languages (parsing is effectively free)

### Other 0.11+ Built-ins

- `gx` keymap opens filepath/URL under cursor (built-in, no plugin needed)
- `gcc` / `gc` for commenting (built-in since 0.10, no Comment.nvim needed)
- `vim.o.winborder` for consistent floating window borders across ALL plugins (0.11+)
- Improved grapheme cluster / emoji rendering (ZWJ support)
- Terminal cursor shape/blink control
- OSC 52 clipboard in terminal buffers
- OSC 8 hyperlinks in terminal
- Mouse popup menu with "Open in web browser", "Go to definition", diagnostics items
- `vim.snippet` API for native snippet support

### Modern API Requirements (Use These, Not Legacy)

```
❌ DEPRECATED                           ✅ USE INSTEAD
──────────────────────────────────────────────────────────
vim.api.nvim_set_keymap()               vim.keymap.set()
vim.loop.fs_stat()                      vim.uv.fs_stat()
vim.fn.system({ "cmd" })                vim.system({ "cmd" }, opts, callback)
vim.diagnostic.disable()                vim.diagnostic.enable(false)
vim.diagnostic.is_disabled()            vim.diagnostic.is_enabled()
:sign-define for diagnostics            vim.diagnostic.config({ signs = {...} })
```

### 0.12 (Development / HEAD) — Be Aware, Don't Depend On

- `vim.text.diff` (renamed from `vim.diff`)
- `chdir()` with scope argument
- `vim.diagnostic.enable(false)` replaces removed `vim.diagnostic.disable()`
- Diagnostic signs via `vim.diagnostic.config` only (legacy `:sign-define` removed)

---

## ARTICLE III — ARCHITECTURAL PRINCIPLES

### Principle 1: Monolithic Organization

The configuration follows a monolithic but modular pattern — everything lives in one repository under `~/.config/nvim/`, organized by domain responsibility, not by "what plugin it belongs to."

```
~/.config/nvim/
├── init.lua                          -- Entry point: require("core") — NOTHING ELSE
├── lazy-lock.json                    -- Lockfile (committed to git)
├── .luarc.json                       -- Lua LSP workspace config (committed)
│
├── lsp/                              -- 0.11+ Native LSP server configs (auto-discovered)
│   ├── lua_ls.lua                    -- Each file returns a config table
│   ├── ts_ls.lua
│   ├── rust_analyzer.lua
│   └── jdtls.lua
│
└── lua/
    ├── core/                         -- The HEART — pure Neovim, ZERO plugin dependencies
    │   ├── init.lua                  -- Bootstrap: leader → options → keymaps → autocmds (explicit order)
    │   ├── options.lua               -- vim.opt, vim.g, vim.o settings ONLY
    │   ├── keymaps.lua               -- Plugin-free keybindings (vanilla vim power)
    │   ├── autocmds.lua              -- Autocommands and augroups ONLY
    │   └── filetypes.lua             -- Custom filetype detection and overrides
    │
    ├── lib/                          -- Shared utilities (pure functions, zero side effects)
    │   ├── icons.lua                 -- Centralized icon definitions (Nerd Font glyphs)
    │   └── helpers.lua               -- Pure utility functions (used in 4+ places minimum)
    │
    ├── config/                       -- Plugin manager bootstrap
    │   └── lazy.lua                  -- lazy.nvim bootstrap + setup() call
    │
    └── plugins/                      -- Plugin specifications (lazy.nvim spec format)
        ├── init.lua                  -- Master importer: { import = "plugins.core" }, etc.
        ├── core/                     -- Essential plugins (colorscheme, treesitter, fuzzy finder)
        │   ├── colorscheme.lua
        │   ├── treesitter.lua
        │   └── telescope.lua         -- OR fzf-lua.lua (pick one, commit to it)
        ├── editor/                   -- Editor enhancement plugins
        │   ├── lsp.lua               -- LSP plugin config (DEPRIORITIZED)
        │   ├── completion.lua        -- Completion engine (DEPRIORITIZED)
        │   ├── diagnostics.lua       -- Diagnostic display (DEPRIORITIZED)
        │   ├── formatting.lua
        │   └── lint.lua
        ├── ui/                       -- Visual/UI plugins
        │   ├── statusline.lua
        │   ├── bufferline.lua
        │   └── explorer.lua
        ├── tools/                    -- Tool integrations
        │   ├── git.lua
        │   └── tmux.lua              -- tmux-nvim navigation integration
        └── lang/                     -- Language-specific plugin configs
            ├── java.lua
            ├── typescript.lua
            └── lua.lua
```

### Principle 2: init.lua Is a One-Liner

```lua
-- ~/.config/nvim/init.lua
require("core")
```

That's it. Leader key, options, keymaps, autocmds, lazy bootstrap — all orchestrated from `core/init.lua`, not here.

### Principle 3: core/ Is Sacred

- `core/` files must NEVER require or reference any plugin
- `core/` must work perfectly with zero plugins installed (vanilla Neovim)
- If Neovim starts with `--clean`, the core/ settings should still produce a usable editor
- `core/` must work identically whether Neovim is running inside tmux, bare Ghostty, or SSH
- **Validation:** `grep -r "require.*plugin" lua/core/` must return EMPTY

### Principle 4: core/init.lua Defines Load Order

```lua
-- ~/.config/nvim/lua/core/init.lua
-- Bootstrap sequence: NEVER deviate from this order

-- 1. Leader key MUST be set before ANY plugin or keymap loads
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- 2. Core modules in deterministic order
require("core.options")
require("core.keymaps")
require("core.autocmds")
require("core.filetypes")

-- 3. Plugin manager (loads AFTER core is fully initialized)
require("config.lazy")
```

### Principle 5: Explicit Over Abstract

```lua
-- ❌ FORBIDDEN: Clever loops/abstractions that hide what's happening
local function setup_all_servers(servers)
  for _, server in ipairs(servers) do
    lspconfig[server].setup(common_config)
  end
end

-- ✅ REQUIRED: Each server in its own lsp/<name>.lua file, configured individually
```

### Principle 6: No DRY Worship

- If two plugin configs share 5 lines of similar setup, COPY THEM
- 3 copies of 10 lines > 1 shared utility that couples everything
- Exception: `lib/icons.lua` (genuinely shared, genuinely stable)
- Exception: `lib/helpers.lua` (pure functions used in 4+ places minimum)

### Principle 7: Comments Document WHY, Not WHAT

```lua
-- ❌ BAD
vim.opt.scrolloff = 8  -- set scrolloff to 8

-- ✅ GOOD
vim.opt.scrolloff = 8  -- Keep 8 lines visible above/below cursor during scroll
```

### Principle 8: One Plugin, One File

- Plugin keybindings live WITH the plugin spec (in `keys = {}`) — NOT in `core/keymaps.lua`
- Plugin-free keybindings (vanilla vim) live in `core/keymaps.lua`

### Principle 9: No Cross-Module Imports Within core/

- Each `core/` file is self-contained
- If the same helper is needed in two core files, COPY it
- The ONLY file that requires other core files is `core/init.lua`

### Principle 10: No pcall() in Core

- If `core/` errors, it should FAIL LOUD and immediately
- This forces us to fix issues rather than running degraded silently
- `pcall()` is acceptable ONLY for optional features (e.g., "restore cursor if mark is valid")

---

## ARTICLE IV — CORE CONFIGURATION STANDARDS

### options.lua — The Settings Bible

```lua
-- path: nvim/lua/core/options.lua
-- Description: All vim.opt, vim.o, vim.g settings. No plugin config. No keymaps.

-- ── Appearance ──────────────────────────────────────────────
vim.opt.termguicolors = true              -- 24-bit RGB color in terminal
vim.opt.number = true                     -- Absolute line numbers
vim.opt.relativenumber = true             -- Relative numbers for jump counting (5j, 12k)
vim.opt.signcolumn = "yes"                -- Always show signcolumn (prevent layout shift)
vim.opt.cursorline = true                 -- Highlight current line
vim.opt.wrap = false                      -- No line wrapping (horizontal scroll instead)
vim.opt.showmode = false                  -- Mode shown in statusline, not cmdline
vim.o.winborder = "rounded"              -- Consistent border on ALL floating windows (0.11+)

-- ── Indentation ─────────────────────────────────────────────
vim.opt.expandtab = true                  -- Spaces, not tabs
vim.opt.shiftwidth = 2                    -- 2-space indent (personal standard)
vim.opt.tabstop = 2                       -- Tab = 2 spaces
vim.opt.softtabstop = 2                   -- Consistent with tabstop
vim.opt.smartindent = true                -- Auto-indent on new lines

-- ── Search ──────────────────────────────────────────────────
vim.opt.ignorecase = true                 -- Case-insensitive search...
vim.opt.smartcase = true                  -- ...unless uppercase is typed
vim.opt.hlsearch = false                  -- Don't persist search highlights
vim.opt.incsearch = true                  -- Show matches as you type

-- ── Behavior ────────────────────────────────────────────────
vim.opt.scrolloff = 8                     -- Keep 8 lines above/below cursor
vim.opt.sidescrolloff = 8                 -- Keep 8 columns left/right of cursor
vim.opt.splitbelow = true                 -- Horizontal splits open below
vim.opt.splitright = true                 -- Vertical splits open right
vim.opt.undofile = true                   -- Persistent undo across sessions (SSD is fast on M4)
vim.opt.swapfile = false                  -- No swap files (we use git)
vim.opt.backup = false                    -- No backup files (we use git)
vim.opt.updatetime = 250                  -- Faster CursorHold events (default 4000ms)
vim.opt.timeoutlen = 300                  -- Faster keymap sequence timeout

-- ── Terminal & Shell ────────────────────────────────────────
-- NOTE: Set vim.opt.shell to your preferred shell once your shell config is rebuilt
-- vim.opt.shell = "/opt/homebrew/bin/fish"
-- vim.opt.shellcmdflag = "-c"

-- ── Clipboard ───────────────────────────────────────────────
vim.opt.clipboard = "unnamedplus"         -- System clipboard integration (uses OSC 52 in modern terminals)

-- ── Completion ──────────────────────────────────────────────
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- ── Folding (Treesitter-powered) ────────────────────────────
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99                   -- Start with all folds open
vim.opt.foldlevelstart = 99

-- ── Performance (M4 Max headroom) ───────────────────────────
vim.opt.redrawtime = 100                  -- Aggressive redraw (CPU is free on M4 Max)
vim.opt.maxmempattern = 50000            -- Handle massive files without pattern memory errors

-- ── Title ────────────────────────────────────────────────────
vim.opt.title = true                      -- Set terminal title to current file
```

### keymaps.lua — Plugin-Free Power Moves

**PHILOSOPHY:** These are vanilla Neovim bindings that work without ANY plugins. HHKB-optimized. Plugin-specific keymaps live WITH their plugin specs (in `keys = {}`), not here.

**tmux NOTE:** `<C-hjkl>` is defined here for Neovim-native split navigation. When the tmux integration plugin is installed (Phase 2), these will be overridden to provide seamless nvim-split ↔ tmux-pane navigation. The core bindings here ensure split navigation works even without tmux.

```lua
-- path: nvim/lua/core/keymaps.lua
-- Description: ALL plugin-free keybindings. Organized by purpose.
--              Plugin keymaps belong in lua/plugins/<category>/<plugin>.lua

local keymap = vim.keymap.set

-- ── UNIVERSAL PATTERNS (adopted by the best, for good reason) ──

-- Move selected lines up/down in visual mode
-- WHY: Rearranging code without cut/paste. Near-universal among power users.
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Join lines without cursor jumping
-- WHY: Default J moves cursor to join point. This preserves position.
keymap("n", "J", "mzJ`z", { desc = "Join lines (cursor stays)" })

-- Half-page jump with centered cursor
-- WHY: Keeps context visible during fast navigation. <C-> is HHKB home-row Ctrl.
keymap("n", "<C-d>", "<C-d>zz", { desc = "Half-page down (centered)" })
keymap("n", "<C-u>", "<C-u>zz", { desc = "Half-page up (centered)" })

-- Search terms stay centered
-- WHY: After searching, you want to SEE the match in context, not at screen edge.
keymap("n", "n", "nzzzv", { desc = "Next search result (centered)" })
keymap("n", "N", "Nzzzv", { desc = "Prev search result (centered)" })

-- ── CLIPBOARD MASTERY ───────────────────────────────────────

-- Paste over selection without losing register
-- WHY: Default paste-over replaces your yank register with what you just deleted.
keymap("x", "<leader>p", '"_dP', { desc = "Paste over without register loss" })

-- Yank to system clipboard explicitly
-- WHY: Even with unnamedplus, explicit clipboard yanks are intentional and self-documenting.
keymap({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
keymap("n", "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })

-- Delete to void register (don't pollute yank)
-- WHY: Protect your yank register when deleting code you don't want to paste.
keymap({ "n", "v" }, "<leader>d", '"_d', { desc = "Delete to void register" })

-- Don't yank with x
-- WHY: Single char delete should not overwrite your carefully yanked text.
keymap("n", "x", '"_x', { desc = "Delete char without yank" })

-- ── WINDOW NAVIGATION ────────────────────────────────────────
-- HHKB: Ctrl is home row left, so <C-hjkl> is extremely comfortable.
-- NOTE: These will be overridden by vim-tmux-navigator (or equivalent) in Phase 2
-- to provide seamless navigation across nvim splits AND tmux panes.
keymap("n", "<C-h>", "<C-w>h", { desc = "Move to left split" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Move to below split" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Move to above split" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Move to right split" })

-- ── WINDOW RESIZING (HHKB: Meta is thumb, NO arrow keys) ────
-- WHY: HHKB has no dedicated arrows. Meta/Alt is thumb-accessible. <M-hjkl> for resize.
keymap("n", "<M-h>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
keymap("n", "<M-l>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })
keymap("n", "<M-j>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
keymap("n", "<M-k>", "<cmd>resize +2<CR>", { desc = "Increase window height" })

-- ── BUFFER MANAGEMENT ───────────────────────────────────────
keymap("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next buffer" })
keymap("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
keymap("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })
keymap("n", "<leader><leader>", "<C-^>", { desc = "Alternate buffer (last file)" })

-- ── TERMINAL MODE ───────────────────────────────────────────
-- WHY: Clean escape path from terminal insert mode back to Normal.
-- NOTE: For persistent terminals, prefer tmux panes over :terminal.
-- Neovim :terminal is for quick one-off commands within the editor.
keymap("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal insert mode" })
keymap("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Terminal: move to left split" })
keymap("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Terminal: move to below split" })
keymap("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Terminal: move to above split" })
keymap("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Terminal: move to right split" })

-- ── QUALITY OF LIFE ─────────────────────────────────────────

-- Quick save
keymap("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })

-- Select all
keymap("n", "<leader>a", "ggVG", { desc = "Select all" })

-- Clear search highlight on Escape
keymap("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })

-- Word replace under cursor (fastest refactor motion in vanilla vim)
keymap("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  { desc = "Replace word under cursor globally" })

-- Make current file executable
keymap("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true, desc = "Make file executable" })

-- Better indenting (stay in visual mode)
-- WHY: Default < and > drop you out of visual mode. This lets you indent repeatedly.
keymap("v", "<", "<gv", { desc = "Indent left (stay selected)" })
keymap("v", ">", ">gv", { desc = "Indent right (stay selected)" })

-- ── QUICKFIX NAVIGATION ─────────────────────────────────────
-- WHY: Quickfix is the primary multi-file navigation tool in vanilla vim.
keymap("n", "<leader>qn", "<cmd>cnext<CR>zz", { desc = "Next quickfix item" })
keymap("n", "<leader>qp", "<cmd>cprev<CR>zz", { desc = "Prev quickfix item" })
keymap("n", "<leader>qo", "<cmd>copen<CR>", { desc = "Open quickfix list" })
keymap("n", "<leader>qc", "<cmd>cclose<CR>", { desc = "Close quickfix list" })
```

### autocmds.lua — Automation Without Plugins

```lua
-- path: nvim/lua/core/autocmds.lua
-- Description: All autocommands and augroups. No plugin config. No keymaps.

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ── Highlight on Yank ───────────────────────────────────────
-- WHY: Visual feedback when yanking. Near-universal standard. Originally TJ DeVries.
augroup("UserYankHighlight", { clear = true })
autocmd("TextYankPost", {
  group = "UserYankHighlight",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
  desc = "Brief highlight on yank for visual feedback",
})

-- ── Remove Trailing Whitespace on Save ──────────────────────
-- WHY: Clean diffs. No noise in git blame. Professional habit.
augroup("UserTrimWhitespace", { clear = true })
autocmd("BufWritePre", {
  group = "UserTrimWhitespace",
  pattern = "*",
  command = [[%s/\s\+$//e]],
  desc = "Remove trailing whitespace on save",
})

-- ── Return to Last Edit Position ────────────────────────────
-- WHY: When reopening a file, you want to be where you left off, not line 1.
augroup("UserLastPosition", { clear = true })
autocmd("BufReadPost", {
  group = "UserLastPosition",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "Return to last edit position when opening file",
})

-- ── Auto-Resize Splits on Terminal Resize ───────────────────
-- WHY: When tmux panes resize or terminal window changes, splits should rebalance.
augroup("UserAutoResize", { clear = true })
autocmd("VimResized", {
  group = "UserAutoResize",
  command = "wincmd =",
  desc = "Auto-resize splits when terminal is resized",
})

-- ── Terminal Buffer Configuration ───────────────────────────
-- WHY: Terminal buffers shouldn't have line numbers or signcolumn.
-- NOTE: For persistent terminals, prefer tmux panes. This is for :terminal one-offs.
augroup("UserTermConfig", { clear = true })
autocmd("TermOpen", {
  group = "UserTermConfig",
  pattern = "*",
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.cmd.startinsert()
  end,
  desc = "Configure terminal buffers: no line numbers, start in insert",
})

-- ── Filetype-Specific Indentation ───────────────────────────
-- DEFAULT is 2-space (covers JS, TS, Java, Lua, YAML, HTML, CSS, etc.)
-- Only override for languages that conventionally require 4-space.
augroup("UserFileTypeOverrides", { clear = true })
autocmd("FileType", {
  group = "UserFileTypeOverrides",
  pattern = { "python", "c", "cpp", "cs", "rust" },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
  desc = "4-space indent for Python/C/C++/C#/Rust (language convention)",
})

-- ── Close Certain Filetypes with q ──────────────────────────
-- WHY: Help, quickfix, man pages should close with a single q keystroke.
autocmd("FileType", {
  group = "UserFileTypeOverrides",
  pattern = { "help", "qf", "man", "lspinfo", "checkhealth" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true, desc = "Close this window" })
  end,
  desc = "Close help/qf/man windows with q",
})
```

---

## ARTICLE V — LAZY.NVIM STANDARDS

### Bootstrap Pattern (config/lazy.lua)

```lua
-- path: nvim/lua/config/lazy.lua
-- Description: lazy.nvim bootstrap and setup. No plugin specs here — those live in plugins/.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },         -- Loads plugins/init.lua which imports subdirectories
  },
  defaults = {
    lazy = true,                    -- All plugins lazy-loaded by default
  },
  install = {
    colorscheme = { "catppuccin", "habamax" },
  },
  checker = {
    enabled = true,                 -- Auto-check for plugin updates
    notify = false,                 -- Don't spam notifications
  },
  change_detection = {
    notify = false,                 -- Don't notify on config file changes
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  ui = {
    border = "rounded",             -- Consistent border style (matches vim.o.winborder)
  },
})
```

### Plugin Spec Rules

```lua
-- ✅ Use opts when possible (lazy.nvim calls setup() for you)
return {
  "plugin/name",
  opts = { setting = "value" },
}

-- ✅ Use config ONLY when you need imperative logic beyond setup()
return {
  "plugin/name",
  config = function(_, opts)
    require("plugin").setup(opts)
    -- Imperative work that opts alone can't express
  end,
}

-- ❌ WRONG: config just to call setup with opts — use opts = {} directly
-- ✅ Plugin-specific keybindings in keys = {} (NOT in core/keymaps.lua)
return {
  "plugin/name",
  keys = {
    { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find Files" },
  },
}
```

### Lazy Loading Strategy

```
Load immediately (lazy = false):  colorscheme, statusline
Load on event VeryLazy:           UI enhancements after startup, tmux navigator
Load on event BufReadPre:         editor plugins when opening files
Load on keymap (keys = {}):       tools triggered by specific bindings
Load on command (cmd = {}):       commands triggered by name
Load on filetype (ft = {}):       language-specific plugins
```

### Native LSP File Pattern (lsp/ directory)

```lua
-- path: nvim/lsp/lua_ls.lua (auto-discovered by vim.lsp.config, no require needed)
return {
  settings = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
      diagnostics = { globals = { "vim" } },
    },
  },
}

-- Enable servers when Phase 2 begins:
-- vim.lsp.enable({ "lua_ls", "ts_ls", "rust_analyzer", "jdtls" })
```

---

## ARTICLE VI — KEYBINDING PHILOSOPHY

### The Namespace System

```
<leader>f  → Find/Files (Telescope/fzf)        <leader>g  → Git operations
<leader>l  → LSP actions (reserved)             <leader>b  → Buffer management
<leader>q  → Quickfix list                      <leader>w  → Write/Save
<leader>t  → Terminal/Toggle                    <leader>s  → Search and replace
<leader>e  → Explorer/File tree                 <leader>d  → Diagnostics (reserved)
<leader>c  → Code actions (reserved)
<leader><leader> → Alternate buffer (last file)
<localleader>    → Buffer-local / filetype-specific actions (comma)
<M-*>            → Meta/Alt for window management (HHKB thumb)
<C-*>            → Ctrl for navigation (HHKB home-row)
```

### The `<C-hjkl>` Problem — Neovim ↔ tmux Seamless Navigation

This is the single most important keybinding decision in the entire PDE. `<C-hjkl>` must mean "move focus in that direction" EVERYWHERE — whether the target is a Neovim split or a tmux pane.

**The solution:** A navigator plugin (vim-tmux-navigator, smart-splits.nvim, or Navigator.nvim) that detects whether you're at a Neovim edge and, if so, sends the movement to tmux instead. Both Neovim AND tmux must be configured for this.

**Neovim side:** Plugin in `plugins/tools/tmux.lua` overrides `<C-hjkl>` with smart navigation. Falls back to vanilla `<C-w>hjkl` if tmux is not present.

**tmux side:** tmux.conf binds `<C-hjkl>` to check if the active pane is running Neovim, and if so, sends the key to Neovim instead of switching tmux panes.

**The contract:**

```
<C-h>  → Move focus left  (nvim split OR tmux pane — seamless)
<C-j>  → Move focus down  (nvim split OR tmux pane — seamless)
<C-k>  → Move focus up    (nvim split OR tmux pane — seamless)
<C-l>  → Move focus right (nvim split OR tmux pane — seamless)
```

This is a Phase 2 integration. In Phase 1, `<C-hjkl>` does vanilla Neovim split navigation.

### Keybinding Sovereignty — Who Owns What

```
LAYER           PREFIX / KEYS           OWNED BY        WHAT IT DOES
──────────────────────────────────────────────────────────────────────────
OS-level        skhd hotkeys            skhd            yabai commands (focus/move windows, spaces)
tmux            <C-Space> + key         tmux            tmux commands (new pane, new window, sessions)
                <C-hjkl>                tmux + nvim     Seamless pane/split navigation (shared)
Neovim          <leader> + key          Neovim          Editor commands (find, git, LSP, etc.)
                <M-hjkl>                Neovim          Window resize (Meta is nvim-only)
                <C-d/u>                 Neovim          Scroll (passthrough from tmux)
Karabiner       Hyper + key             Karabiner       System-wide (app switching, custom layers)
```

**Key rules:**

- **tmux prefix:** `<C-Space>` (not `<C-a>` or `<C-b>`) — keeps `<C-a>` free for shell line-beginning, and `<C-b>` free for Neovim page-up
- **skhd** uses its own modifier combos (typically Hyper or cmd-based) — NO overlap with Neovim or tmux
- **`<C-hjkl>`** is the ONLY shared binding — resolved by the navigator plugin
- **`<M-hjkl>`** is Neovim-exclusive — tmux does NOT use Meta+hjkl
- **`<leader>`** is Neovim-exclusive — Space only means "leader" inside Neovim

### HHKB Keybinding Comfort Tiers

```
TIER 1 — Best (use for most frequent actions):
  <leader> + single key     Space (thumb) + home row
  <C-hjkl>                  Ctrl (home row left) + nav keys

TIER 2 — Good (secondary actions):
  <M-hjkl>                  Meta/Alt (thumb) + nav keys
  <leader> + two keys       Space + chord

TIER 3 — Acceptable (infrequent actions):
  <C-S-key>                 Ctrl+Shift+key

TIER 4 — AVOID (requires Fn layer or gymnastics):
  <F1>-<F12>                Fn+number (right pinky + top row)
  Arrow key combos          Fn+[;'/ (right pinky + home row)
  <C-Up/Down/Left/Right>    Ctrl+Fn+key (BANNED — double layer)
```

### Patterns From The Best (Absorb Principles, Not Keybinds)

**ThePrimeagen:** Visual J/K line moving, centered scrolling (`<C-d>zz`), void register deletes, word replacement under cursor. **Principle:** Reduce cognitive overhead. Bindings should require zero thinking.

**TJ DeVries:** Yank highlight, kickstart.nvim philosophy (understand every line), Telescope as universal fuzzy interface, builtin LSP over wrappers. **Principle:** The best config is one you understand completely.

**Universal:** `<C-hjkl>` split nav, Space leader, relative numbers, `zz` after jumps, quickfix for multi-file ops, `<leader><leader>` alternate buffer. **Principle:** Master the primitives before adding abstractions.

---

## ARTICLE VII — HARD RULES

### Rule 1: NO PLUGIN DUPLICATES BUILT-IN 0.11+ FEATURES

```
❌ BANNED                               ✅ USE INSTEAD
──────────────────────────────────────────────────────────
vim-commentary / Comment.nvim            gcc/gc (built-in 0.10+)
nvim-lspconfig (basic setup)             lsp/<name>.lua + vim.lsp.enable()
lsp_lines.nvim                           vim.diagnostic virtual_lines (0.11+)
neoclip                                  vim registers + OSC 52
vim-illuminate (basic)                   Built-in LSP documentHighlight
```

### Rule 2: STARTUP TIME < 50ms

Measure: `nvim --startuptime /tmp/startup.log`. Use `lazy = true` default.

### Rule 3: ONE OF EACH

One colorscheme. One fuzzy finder. One completion engine. One file explorer. One statusline. One tmux navigator.

### Rule 4: EVERY KEYMAP HAS desc

No exceptions. Enables which-key discovery and `:map` readability.

### Rule 5: MODERN APIS ONLY

`vim.keymap.set` not `nvim_set_keymap`. `vim.uv` not `vim.loop`. `vim.system()` not `vim.fn.system()`.

### Rule 6: GIT-TRACKED

Commit: `lazy-lock.json`, `.luarc.json`, `spell/`, `lsp/`. Don't commit: generated files, plugin data.

### Rule 7: NEOVIM IS NOT A TERMINAL MULTIPLEXER

tmux handles sessions, panes, and persistent terminals. Neovim's `:terminal` is for quick one-off commands. Do NOT install terminal management plugins that duplicate tmux functionality (toggleterm for basic terminal toggling is acceptable; session managers are not).

---

## ARTICLE VIII — CURRENT PRIORITY STACK

### 🔴 ACTIVE FOCUS — Phase 1 (Build Now)

1. `core/init.lua` — Bootstrap sequence
2. `core/options.lua` — Rock-solid settings
3. `core/keymaps.lua` — Plugin-free power moves
4. `core/autocmds.lua` — Smart automations
5. `core/filetypes.lua` — Filetype handling
6. `config/lazy.lua` — Clean bootstrap
7. `lib/icons.lua` — Centralized glyphs
8. `plugins/core/colorscheme.lua` — Visual foundation
9. `plugins/core/treesitter.lua` — Syntax foundation

### 🟡 SECONDARY — Phase 2

10. Fuzzy finder
11. File explorer
12. Statusline
13. Git integration
14. `lsp/` native configs
15. tmux-nvim navigation integration (`plugins/tools/tmux.lua`)

### 🔵 DEPRIORITIZED — Phase 3

16. LSP plugins
17. Completion
18. Diagnostics display
19. Formatting/linting
20. Language configs
21. DAP/Debugging

---

## ARTICLE IX — LLM RESPONSE PROTOCOL

### First Response Checklist (BEFORE changing anything)

When starting a NEW conversation about this config, ALWAYS ask for:

1. Current `~/.config/nvim` file tree
2. Contents of `init.lua` + all `lua/core/*` + `lua/config/lazy.lua`
3. My top daily workflows (if not already known)
4. THEN propose — never prescribe blind

### Code Generation Rules

1. **COMPLETE files only** — no snippets, no `-- ... rest of file`
2. **File path as first comment** — `-- path: nvim/lua/core/options.lua`
3. **CHANGELOG on modified files** — `-- CHANGELOG: 2026-02-03 | Added winborder | ROLLBACK: Delete line 14`
4. **Section headers** — `-- ── Section Name ──────`
5. **desc on every keymap and autocmd**
6. **`{ clear = true }` on every augroup**
7. Modern APIs only: `vim.keymap.set`, `vim.uv`, `vim.system()`, `<cmd>` prefix

### Keybinding Consultation

- What it does + WHY it's useful
- Conflicts with Neovim defaults?
- Conflicts with tmux prefix or skhd bindings?
- HHKB comfort tier (Article VI)
- Would `<M->` be better than `<C->` for this?

### Plugin Consultation

- Built-in in 0.11+? (check Rule 1)
- Does tmux already handle this? (check Rule 7)
- Actively maintained? (< 6 months)
- Conflicts with current stack? (Rule 3)
- Provide lazy.nvim spec format, not raw setup()

### Code Review Protocol

1. Call out dead code
2. Call out Neovim-default redundancy
3. Call out plugin redundancy with built-ins
4. Call out tmux redundancy (terminal/session plugins duplicating tmux)
5. Call out HHKB violations (arrow keys, F-keys)
6. Call out architecture violations (plugin refs in core/)
7. Call out keybinding collisions across layers (nvim/tmux/skhd)
8. **Suggest removals** — leaner is better

### Pre-Merge Checklist

```
[ ] init.lua is still a one-liner?
[ ] core/ free of plugin references? (grep -r "require.*plugin" lua/core/)
[ ] No cross-module imports in core/?
[ ] Every keymap has desc?
[ ] Every augroup has { clear = true }?
[ ] No HHKB-hostile bindings? (arrows, F-keys)
[ ] No keybinding collisions with tmux prefix (<C-Space>)?
[ ] Using modern APIs? (vim.uv, vim.system, vim.keymap.set)
[ ] Using 0.11+ built-ins instead of plugins where applicable?
[ ] Not duplicating tmux functionality in Neovim?
```

---

## ARTICLE X — SAFETY & RECOVERABILITY

### Transition Protocol

- When remapping muscle-memory bindings: keep BOTH old and new active for 7 days
- Use `vim.notify("Deprecated: use <new> instead of <old>", vim.log.levels.WARN)` for transitions
- Every CHANGELOG includes a ROLLBACK instruction

### Validation After Any Change

```
:checkhealth                          -- General health
:checkhealth lazy                     -- Plugin manager
:checkhealth lsp                      -- LSP (Phase 2+)
nvim --startuptime /tmp/s.log         -- Performance check
grep -r "require.*plugin" lua/core/   -- Core isolation (must be empty)
```

---

## ARTICLE XI — PHILOSOPHICAL REMINDERS

> "Cowboys don't use umbrellas." I forge my own bindings, my own workflow, my own patterns. I study the best — ThePrimeagen's speed, TJ's depth, the community's wisdom — but I absorb principles, not cargo-cult configurations.

> The editor should disappear. Every binding, every setting, every plugin serves one purpose: reducing friction between intent and execution.

> Less is more. A 200-line core config I understand completely beats a 2000-line distro I'm afraid to touch. Remove before you add.

> Three AM test: If I'm debugging production at 3 AM, every binding should be muscle memory, every option should make sense, nothing should surprise me.

> The toolchain is one instrument. Neovim, tmux, Ghostty, yabai — they breathe as one system. `<C-hjkl>` means "move focus" everywhere. One mental model, multiple tools.

---

_Version 2.4 | February 2026 | Neovim 0.11.x (0.12 aware) | lazy.nvim stable_
_macOS Tahoe 26.2 (M4 Max) | HHKB Professional Hybrid Type-S | tmux + yabai (parallel layers)_

<!-- CHANGELOG v2.4 (2026-02-04):
  - Upgraded quality bar from "Top 1%" to "Top 0.1%"
  - Added tmux as parallel multiplexing layer alongside yabai (not competing)
  - Added Karabiner-Elements, Starship, yazi, eza to toolchain table
  - Added "The Two Spatial Layers" section with ASCII architecture diagram
  - Added Karabiner-Elements role and dependency rules
  - Added full toolchain rebuild order
  - Added `plugins/tools/tmux.lua` to directory tree
  - Added "<C-hjkl> Problem" section — seamless nvim↔tmux navigation contract
  - Added "Keybinding Sovereignty" table — who owns what across all layers
  - Defined tmux prefix as <C-Space> (not <C-a>/<C-b>)
  - Added Rule 7: "Neovim Is Not A Terminal Multiplexer"
  - Added tmux navigator to Phase 2 priority stack
  - Updated keybinding consultation to check tmux/skhd collisions
  - Updated code review protocol to catch tmux redundancy
  - Updated pre-merge checklist for tmux collision checks
  - Added tmux-aware comments to keymaps.lua and autocmds.lua
  - Added fifth philosophical reminder about unified toolchain
  ROLLBACK: Revert to v2.3 constitution -->
