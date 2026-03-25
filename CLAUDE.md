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

**skhd** (`skhd/`): Profile-based architecture using symlink swap. Uses skhd-zig fork.

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

Visual stack indicators for yabai. Config lives in `~/.config/hammerspoon/` and is symlinked from `~/.hammerspoon/init.lua`.

```
hammerspoon/
├── init.lua                  # Entry point — IPC, module loading, startup alert
├── modules/
│   ├── reload.lua            # Auto-reload on .lua save via hs.pathwatcher
│   ├── stack-indicators.lua  # App icon pills for yabai window stacks
│   └── utils.lua             # yabaiQuery(), isDarkMode(), debounce()
```

**Stack indicators:** Queries `yabai -m query --windows --space`, groups by `stack-index`, draws rounded pills with app icons in the yabai left padding gap. Click-to-focus, theme-aware (light/dark), debounced redraws.

**Reload:** Auto-reloads on any `.lua` file save. Also reloaded by `Hyper+Q` (via `yr` fish function alongside yabai/skhd). IPC enabled for `hs -c` CLI commands.

## tmux (`tmux/`)

Config in `tmux.conf`. Plugins managed by TPM: tmux-resurrect, tmux-continuum, vim-tmux-navigator. Vi copy-mode with `y` → pbcopy.

## Pre-commit Hook

A 3-layer pre-commit hook (`.pre-commit-hook`) prevents accidental secret leaks:

1. **Path blocking** — hard-blocks `stripe/`, `gh/`, and any path matching `credentials`, `env.bak`, `.env`. Never bypassable.
2. **Content scanning** — 31 regex patterns catching private keys, API keys (`sk_test_`, `ghp_`, `AKIA`, etc.), passwords, DB URLs, cloud creds.
3. **Allowlist** — `.hook-allowlist` skips content scanning for files that reference patterns but aren't secrets (e.g., the hook itself).

**Install after cloning:** `cp .pre-commit-hook .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`

## LLM Cross-Review System

Adversarial multi-model code review via templated intake documents. Send code to 5+ web LLMs independently, triage findings, fix real issues, iterate until convergence (all PASS).

```bash
./scripts/generate-intake.sh <template-name>
```

Templates at `scripts/templates/rounds/*.md`. Use `{{FILE:path/relative/to/repo}}` markers. Output persisted to `scripts/templates/generated/llm.intake.<name>.md`. Review loop: generate -> feed to 5 web LLMs -> triage -> fix -> repeat until clean.

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
