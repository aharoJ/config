# nvim-rebuild — Decision Log

> This becomes the constitution once patterns emerge from real usage.
> For now, just track what we chose and why.

## Decisions

### 2026-02-03 — Initial Setup
- **NVIM_APPNAME**: Using `nvim-rebuild` so old config stays usable via `nvim`
- **Alias**: `nvr` in fish shell launches the rebuild config
- **Leader**: Space (set in init.lua before lazy loads, per official recommendation)
- **Indent**: 2-space global default. 4-space for Python, Rust, Java, Kotlin, Go. Go uses tabs.
- **Structure**: Official lazy.nvim "Structured Setup" — bootstrap in `config/lazy.lua`, specs in `plugins/*.lua`
- **Philosophy**: Add plugins only when you feel the pain. If stock nvim handles it, skip the plugin.

### 2026-02-03 — lazy.nvim Conventions (from official docs)
- **`opts` over `config`**: Per lazy.nvim docs — "Always use opts instead of config when possible."
  - `opts` = the table passed to `require(plugin).setup(opts)` — lazy handles the call automatically
  - `config` = only when you need custom logic beyond setup (loading extensions, calling vim.cmd, etc.)
- **`main`**: Use when the setup module name differs from the plugin name (e.g. treesitter → `nvim-treesitter.configs`)
- **No `plugins/init.lua`**: lazy auto-discovers `plugins/*.lua` — no barrel file needed
- **Bootstrap lives in `config/lazy.lua`**: Separates installation logic from plugin specs

### 2026-02-03 — Neovim 0.11 Audit (from official news-0.11)
- **DO NOT override built-in LSP keymaps** — 0.11 ships defaults for rename, references,
  implementation, code action, document symbols, hover, and signature help.
  Our config ONLY adds ergonomic aliases (`gd`, `gD`, `<leader>ca`, `<leader>rn`, `<leader>e`, `<leader>ws`).
- **DO NOT override diagnostic navigation** — `[d`/`]d`, `[D`/`]D`, `<C-w>d` are built-in.
- **DO NOT override buffer navigation** — `[b`/`]b`, `[B`/`]B` are built-in.
  We keep `<S-h>`/`<S-l>` as ergonomic aliases.
- **`vim.diagnostic.goto_prev/goto_next` are deprecated** — use `vim.diagnostic.jump()`.
  We don't call these at all since we rely on the built-in `[d`/`]d` defaults.
- **Virtual text is OFF by default in 0.11** — we explicitly opt in via `vim.diagnostic.config()`.
- **`vim.lsp.config()` + `vim.lsp.enable()`** — new native LSP setup available.
  We use mason + lspconfig for now (still recommended, more convenient for multi-language).
  Can revisit if we want to drop plugins later.

## Neovim 0.11 Default Keymaps Reference
```
── LSP (active when server attached) ──
K             hover docs
grn           rename
grr           references
gri           implementation
gra           code action (n + v)
gO            document symbols
<C-S>         signature help (insert)

── Diagnostics ──
[d / ]d       prev / next diagnostic
[D / ]D       first / last diagnostic
<C-w>d        open diagnostic float

── Buffers (vim-unimpaired style) ──
[b / ]b       prev / next buffer
[B / ]B       first / last buffer

── Other ──
[q / ]q       quickfix navigation
[l / ]l       location list navigation
[<Space>      add blank line above
]<Space>      add blank line below
```

## Pain Points
<!-- Track things that annoy you. These become plugin candidates. -->

## Killed Ideas
<!-- Things we tried and removed. Prevents re-adding bad ideas. -->
