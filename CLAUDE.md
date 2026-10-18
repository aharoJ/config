# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal dotfiles for macOS (Apple Silicon). The repo root is `~/.config/`; tmux is managed in a separate repo (see below). There is no build system or CI for this repo. Dotfile changes are applied by reloading the relevant tool.

Ghostty has its own repo at `~/.repository/ghostty` (`main`, published as `aharoJ/ghostty`); `~/.config/ghostty` is its live `private` worktree. This repo ignores `/ghostty/`.

Starship has its own repo at `~/.repository/starship` (`main`, published as `aharoJ/starship`). Public `main` was cleaned to `starship.toml`, `README.md` and `img/`; old versions are tags `v0.1.0`–`v0.4.0`. `~/.config/starship` is its live `private` worktree. This repo ignores `/starship/`.

Yazi has its own repo at `~/.repository/yazi` (`main`, published as `aharoJ/yazi`); `~/.config/yazi` is its live `private` worktree. This repo ignores `/yazi/`.

## Reload Commands

| Tool       | Reload command                                                |
| ---------- | ------------------------------------------------------------- |
| Fish shell | `source ~/.config/fish/config.fish`                           |
| Neovim     | `:Lazy sync` (plugins) or restart nvim                        |
| tmux       | `tmux source-file ~/.config/tmux/tmux.conf` (or `prefix + r`) |
| yabai      | `yabai --restart-service`                                     |
| skhd       | `skhd --restart-service`                                      |
| Starship   | Automatic on new prompt                                       |
| Ghostty    | `Cmd+Shift+R` or Ghostty → Reload Configuration                |
| Karabiner  | Automatic on JSON save                                        |
| Hammerspoon| Automatic on `.lua` save (pathwatcher), or `hs -c "hs.reload()"` |

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

`~/.repository/yabai` holds the real repo on `main` (empty and local for now); `~/.config/yabai` is its live `private` worktree. This repo ignores `/yabai/`. The existing LaunchAgent still reads `~/.config/yabai/yabairc`.

**skhd** (`skhd/`): Profile-based architecture using symlink swap. Uses skhd-zig fork.

`~/.repository/skhd` holds the real repo on `main` (empty and local for now); `~/.config/skhd` is its live `private` worktree. This repo ignores `/skhd/`. The existing LaunchAgent still reads `~/.config/skhd/skhdrc`, with `modules/active` pointing at the selected profile.

```
skhd/
├── skhdrc                    # Entry point — loads shared/ + active/
├── modules/
│   ├── active → stack/       # Symlink swapped by `yp` fish function + skhd -r
│   ├── shared/               # Always loaded (apps, scripts, services)
│   ├── stack/                # Stack-only bindings (primary workflow)
│   └── bsp/                  # BSP-only bindings
└── scripts/                  # Helper scripts for skhd bindings
```

Profile switching: `Hyper+T` (stack) or `Hyper+P` (BSP) calls the `yp` fish function which swaps `modules/active` symlink and reloads skhd. Stack and BSP bindings are completely isolated — no fallback chains, no silent no-ops.

**SIP is fully enabled** — `window --space`, `space --focus`, scratchpad, opacity, animations, and shadows are all unavailable. Only bind commands that work without the scripting addition.

**Karabiner** (`karabiner/`): CapsLock → Hyper (Ctrl+Opt+Shift+Cmd). Escape held → Hyper, tapped → Escape. Config is auto-generated JSON — edit with care.

### Key Sovereignty

- `Hyper + key` → skhd/yabai
- `Ctrl + h/j/k/l` → RESERVED for Neovim ↔ tmux navigation (never bind in skhd)
- `Alt + h/j/k/l` → RESERVED for Neovim resize
- `Ctrl + Space` → tmux prefix
- `Hyper + 1-9, [, ]` → Karabiner-claimed (desktop switching, backlight)

## Hammerspoon (`hammerspoon/`)

Visual stack indicators and display helpers for yabai. Hammerspoon's `MJConfigFile` preference points directly to `~/.config/hammerspoon/init.lua`; `~/.hammerspoon` is absent. `~/.repository/hammerspoon` holds the real repo on `main` (published as `aharoJ/hammerspoon`), and `~/.config/hammerspoon` is its live `private` worktree. This repo ignores `/hammerspoon/`.

```
hammerspoon/
├── init.lua                  # Entry point — IPC, module loading, startup alert
├── modules/
│   ├── reload.lua            # Auto-reload on .lua save via hs.pathwatcher
│   ├── stack-indicators.lua  # App icon pills for yabai window stacks
│   ├── dock-on-display.lua   # Reset Dock after connected screen membership changes
│   └── utils.lua             # yabaiQuery(), isDarkMode(), debounce()
```

**Stack indicators:** Queries `yabai -m query --windows --space`, filters visible windows with positive `stack-index` and sorts by that index. With at least two matching windows, draws app-icon pills to the left of the first window, highlights focus and adapts colors to light/dark mode. Redraws are debounced.

**Display changes:** Resets Dock after a three-second debounce only when connected screen identities change; startup and unchanged screen membership do not reset Dock.

**Reload:** Auto-reloads on any `.lua` file save. Manual reload: `hs.reload()` in the Hammerspoon console or `hs -c "hs.reload()"` with the CLI. IPC is enabled. The current `yr` Fish function restarts yabai/skhd only.

## tmux (separate repo)

`~/.repository/tmux` is the main checkout of `aharoJ/tmux` on branch `main` and holds the real `.git` directory. `~/.config/tmux` is its `private` worktree and the live config. This repo ignores `/tmux/`; tmux plugins, relay tools and tests belong to the separate repo.

Known leftover: `~/.local/share/relay-stable` is still a worktree of `~/.config/.git`, built from config's old `tmux/` history.

## Pre-commit Hook

A 3-layer pre-commit hook (`.pre-commit-hook`) prevents accidental secret leaks:

1. **Path blocking** — hard-blocks `stripe/`, `gh/`, and any path matching `credentials`, `env.bak`, `.env`. Never bypassable.
2. **Content scanning** — 31 regex patterns catching private keys, API keys (`sk_test_`, `ghp_`, `AKIA`, etc.), passwords, DB URLs, cloud creds.
3. **Allowlist** — `.hook-allowlist` skips content scanning for files that reference patterns but aren't secrets (e.g., the hook itself).

**Install after cloning:** `cp .pre-commit-hook .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`

## Severity Classification

- **P0**: Data corruption, security holes, silent wrong behavior
- **P1**: Functional bugs that affect correctness but have workarounds
- **P2**: Code quality, edge cases unlikely in normal use
- **P3**: Style, naming, minor improvements

## Conventions

- Config files use header comments with `path:`, `description:`, `patched:`, and `date:` annotations.
- Repo-level change history lives in `CHANGELOG.md`.
- Yabai rules use anchored regex (`^...$`) for app matching.
- The `nvim/` directory (without `-rebuild` suffix) is legacy — do not modify it.
