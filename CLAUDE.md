# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal dotfiles for macOS (Apple Silicon). The repo root is `~/.config/` and is managed as a single git repo. There is no build system, test suite, or CI — changes are applied by reloading the relevant tool.

## Reload Commands

| Tool       | Reload command                                                |
| ---------- | ------------------------------------------------------------- |
| Fish shell | `source ~/.config/fish/config.fish`                           |
| Neovim     | `:Lazy sync` (plugins) or restart nvim                        |
| tmux       | `tmux source-file ~/.config/tmux/tmux.conf` (or `prefix + r`) |
| yabai      | `yabai --restart-service`                                     |
| skhd       | `skhd --restart-service`                                      |
| Starship   | Automatic on new prompt                                       |
| Ghostty    | Automatic on config save                                      |
| Karabiner  | Automatic on JSON save                                        |

## Neovim (`nvim-rebuild/`)

The active Neovim config uses `NVIM_APPNAME=nvim-rebuild` (aliased as `n` in fish). The old `nvim/` directory exists but is not the active config.

**Boot sequence:** `init.lua` → `core/init.lua` (sets leader=Space, then loads options → keymaps → autocmds → filetypes) → `config/lazy.lua` (lazy.nvim bootstrap).

**Plugin organization:** `lua/plugins/init.lua` imports subdirectories:

- `plugins/core/` — colorscheme (kanagawa), telescope, treesitter, which-key
- `plugins/editor/` — autopairs, completion, formatting, lint, lsp
- `plugins/lang/` — language-specific: java, json, markdown, react, rust
- `plugins/tools/` — git, tmux-navigator
- `plugins/ui/` — file explorer, statusline

**LSP configs** live in `lsp/` (top-level, using Neovim 0.11+ native LSP dir convention): basedpyright, bashls, eslint, fish_lsp, jsonls, lemminx, lua_ls, marksman, tailwindcss, taplo, ts_ls.

**All plugins are lazy-loaded by default** (`defaults.lazy = true` in lazy.lua).

## Fish Shell (`fish/`)

- `config.fish` — env vars, brew path, interactive aliases/abbrs
- `internal/` — subdirs auto-added to `fish_function_path` at startup
- `functions/` — standard fish autoloaded functions
- `conf.d/` — config snippets sourced on startup
- Version managers: jenv (Java), fnm (Node), pyenv (Python), direnv

## Window Management

**yabai** (`yabai/`): Neutral base config in `yabairc` — no layout opinion. Layout-specific settings (BSP, stack, float) live in `profiles/`. SIP is fully enabled (no scripting addition).

**skhd** (`skhd/`): Modular — `skhdrc` is entry point that `.load`s modules from `modules/` (navigation, manipulation, layout, resize, services, apps, scripts). Uses skhd-zig fork.

**Karabiner** (`karabiner/`): CapsLock → Hyper (Ctrl+Opt+Shift+Cmd). Escape held → Hyper, tapped → Escape. Config is auto-generated JSON — edit with care.

### Key Sovereignty

- `Hyper + key` → skhd/yabai
- `Ctrl + h/j/k/l` → RESERVED for Neovim ↔ tmux navigation (never bind in skhd)
- `Alt + h/j/k/l` → RESERVED for Neovim resize
- `Ctrl + Space` → tmux prefix
- `Hyper + 1-9, [, ]` → Karabiner-claimed

## tmux (`tmux/`)

Config in `tmux.conf`. Plugins managed by TPM: tmux-resurrect, tmux-continuum, vim-tmux-navigator. Vi copy-mode with `y` → pbcopy.

## Conventions

- Config files use header comments with `path:`, `description:`, `CHANGELOG:`, and `ROLLBACK:` annotations.
- Yabai rules use anchored regex (`^...$`) for app matching.
- The `nvim/` directory (without `-rebuild` suffix) is legacy — do not modify it.
