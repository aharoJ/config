-- path: nvim/lua/core/options.lua
-- Description: All vim.opt, vim.o, vim.g settings. No plugin config. No keymaps.
-- CHANGELOG: 2026-02-03 | Full rewrite aligned to constitution v2.2 | ROLLBACK: Replace with previous options.lua
-- CHANGELOG: 2026-02-03 | Enabled swap/backup, added recovery dirs | ROLLBACK: Set swapfile=false, backup=false, remove dir lines

-- ── Appearance ──────────────────────────────────────────────
vim.opt.termguicolors = true              -- 24-bit RGB color in terminal
vim.opt.number = true                     -- Absolute line numbers
vim.opt.relativenumber = true             -- Relative numbers for jump counting (5j, 12k)
vim.opt.signcolumn = "yes"                -- Always show signcolumn (prevent layout shift from LSP/git)
vim.opt.cursorline = true                 -- Highlight current line
vim.opt.wrap = false                      -- No line wrapping (horizontal scroll instead)
vim.opt.showmode = false                  -- Mode shown in statusline plugin, not cmdline
vim.o.winborder = "rounded"               -- Consistent border on ALL floating windows (0.11+)

-- ── Indentation (2-space default: JS/TS/Java/Lua/YAML standard) ─
vim.opt.expandtab = true                  -- Spaces, not tabs
vim.opt.shiftwidth = 2                    -- 2-space indent
vim.opt.tabstop = 2                       -- Tab = 2 spaces
vim.opt.softtabstop = 2                   -- Consistent with tabstop
vim.opt.smartindent = true                -- Auto-indent on new lines

-- ── Search ──────────────────────────────────────────────────
vim.opt.ignorecase = true                 -- Case-insensitive search...
vim.opt.smartcase = true                  -- ...unless uppercase is typed
vim.opt.hlsearch = false                  -- Don't persist search highlights (no need for :noh dance)
vim.opt.incsearch = true                  -- Show matches as you type

-- ── Behavior ────────────────────────────────────────────────
vim.opt.scrolloff = 8                     -- Keep 8 lines above/below cursor during scroll
vim.opt.sidescrolloff = 8                 -- Keep 8 columns left/right of cursor
vim.opt.splitbelow = true                 -- Horizontal splits open below
vim.opt.splitright = true                 -- Vertical splits open right
vim.opt.updatetime = 250                  -- Faster CursorHold events (default 4000ms is sluggish)
vim.opt.timeoutlen = 150                  -- Faster keymap sequence timeout

-- ── Recovery & Persistence ──────────────────────────────────
-- WHY: Git only protects committed work. These protect EVERYTHING —
vim.opt.undofile = true                   -- Persistent undo across sessions (SSD is fast on M4 Max)
vim.opt.swapfile = true                   -- Crash recovery: if terminal dies, recover unsaved changes
vim.opt.backup = true                     -- Keep pre-save copy: safety net for bad saves beyond git
vim.opt.writebackup = true                -- Backup during write, deleted after success (default, made explicit)
vim.opt.undolevels = 10000                -- Deep undo history (M4 Max doesn't care)
vim.opt.undoreload = 10000                -- Undo persists even after :e reload
vim.opt.confirm = true                    -- Ask to save instead of erroring on :q

-- Recovery directories (keep project trees clean)
-- WHY: Without these, swap/backup/undo files litter your working directories.
-- Trailing // encodes the full file path in the filename (prevents collisions).
local data = vim.fn.stdpath("data")
vim.opt.undodir = { data .. "/undo//" }
vim.opt.directory = { data .. "/swap//" }
vim.opt.backupdir = { data .. "/backup//" }

-- ── Clipboard ───────────────────────────────────────────────
vim.opt.clipboard = "unnamedplus"         -- System clipboard integration (uses OSC 52 in modern terminals)

-- ── Completion ──────────────────────────────────────────────
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- ── Folding (Treesitter-powered, 0.11+) ────────────────────
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99                   -- Start with all folds open
vim.opt.foldlevelstart = 99              -- New buffers also start fully unfolded
vim.opt.foldtext = ""                    -- Show first line of fold cleanly (0.11+, no cruft)


-- ── Performance (M4 Max has headroom to spare) ──────────────
vim.opt.redrawtime = 100                  -- Aggressive redraw timeout (CPU is free on Apple Silicon)
vim.opt.maxmempattern = 50000             -- Handle massive files without pattern memory errors

-- ── Terminal & Shell ────────────────────────────────────────
-- NOTE: Set vim.opt.shell once Fish shell config is rebuilt
vim.opt.shell = "/opt/homebrew/bin/fish"
vim.opt.shellcmdflag = "-c"

-- ── Mouse ───────────────────────────────────────────────────
vim.opt.mouse = "a"                       -- Enable mouse in all modes (useful for resizing splits)

-- ── Scrolling ───────────────────────────────────────────────
vim.opt.smoothscroll = true               -- Smooth visual scrolling (0.10+, free on M4 Max + Ghostty)

-- ── Visual Block ────────────────────────────────────────────
vim.opt.virtualedit = "block"             -- Allow cursor past line end in visual block mode

-- ── Visual Chrome ───────────────────────────────────────────
vim.opt.fillchars = {
  fold = " ",                             -- Clean fold markers
  eob = " ",                              -- Hide ~ on empty lines past EOF
  diff = "╱",                             -- Diagonal for deleted diff lines
}

-- ── Title ───────────────────────────────────────────────────
vim.opt.title = true                      -- Set terminal title to current file
