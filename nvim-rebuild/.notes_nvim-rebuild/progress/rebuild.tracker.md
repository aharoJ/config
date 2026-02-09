# 🔥 PDE Rebuild Tracker

> Nuking everything. Rebuilding from scratch. Top 0.1% craftsmanship.
> Every tool earns its place. Every config is intentional.

---

## The Stack

| #   | Tool                   | Role                                           | Principle                                                      | Status               |
| --- | ---------------------- | ---------------------------------------------- | -------------------------------------------------------------- | -------------------- |
| 1   | **Karabiner-Elements** | The translator — keyboard firmware in software | HHKB remapping, Hyper key, layer logic                         | ✅                   |
| 2   | **Neovim**             | The brain — editing, LSP, code intelligence    | Built first, everything else adapts to it                      | ✅                   |
| 3   | **Ghostty**            | The glass — fast GPU rendering, true color     | Serves Neovim's rendering needs, stays invisible               | ✅                   |
| 4   | **tmux**               | The multiplexer — sessions, panes, persistence | Micro spatial layer inside the terminal                        | ✅                   |
| 5   | **yabai **             | The spatial layer — OS-level window tiling     | Macro spatial layer, harmonizes with Neovim's `<M->` namespace | ✅                   |
| 5   | **skhd**               | The spatial layer — OS-level window tiling     | Macro spatial layer, harmonizes with Neovim's `<M->` namespace | ✅                   |
| 6   | **Fish + Starship**    | The shell — commands, prompt, environment      | Fast, no config debt, stays out of Neovim's way                | ✅                   |
| 7   | **yazi**               | The navigator — terminal file manager          | Complements, not replaces, Neovim's explorer                   | ⬜                   |
| 8   | **eza**                | The eyes — modern ls with git integration      | Tiny utility, zero config surface                              | ⬜                   |
| 9   | **Neovim plugins**     | Surgical additions                             | Only after core is rock-solid                                  | ⬜Queued (Phase 2/3) |

---

## Neovim Build Phases

### Phase 1 — Core

| #   | File                           | Purpose                      | Status |
| --- | ------------------------------ | ---------------------------- | ------ |
| 1   | `core/init.lua`                | Bootstrap sequence           | ✅     |
| 2   | `core/options.lua`             | Rock-solid settings          | ✅     |
| 3   | `core/keymaps.lua`             | Plugin-free power moves      | ✅     |
| 4   | `core/autocmds.lua`            | Smart automations            | ✅     |
| 5   | `core/filetypes.lua`           | Filetype handling            | ✅     |
| 6   | `config/lazy.lua`              | Plugin manager bootstrap     | ✅     |
| 7   | `lib/icons.lua`                | Centralized glyphs           | ✅     |
| 8   | `plugins/core/colorscheme.lua` | kanagawa — visual foundation | ✅     |
| 9   | `plugins/core/treesitter.lua`  | Syntax foundation            | ✅     |

### Phase 2 — Navigation & UI

| #   | File                         | Purpose                   | Status |
| --- | ---------------------------- | ------------------------- | ------ |
| 10  | `plugins/core/telescope.lua` | Fuzzy finder              | ⬜     |
| 11  | `plugins/ui/explorer.lua`    | File explorer             | ⬜     |
| 12  | `plugins/ui/statusline.lua`  | Statusline                | ⬜     |
| 13  | `plugins/tools/git.lua`      | Git integration           | ⬜     |
| 14  | `lsp/*.lua`                  | Native LSP server configs | ⬜     |
| 15  | `plugins/tools/tmux.lua`     | tmux ↔ nvim navigation    | ⬜     |

### Phase 3 — Editor Intelligence

| #   | File                             | Purpose                   | Status |
| --- | -------------------------------- | ------------------------- | ------ |
| 16  | `plugins/editor/lsp.lua`         | LSP plugin config         | ⬜     |
| 17  | `plugins/editor/completion.lua`  | Completion engine         | ⬜     |
| 18  | `plugins/editor/diagnostics.lua` | Diagnostic display        | ⬜     |
| 19  | `plugins/editor/formatting.lua`  | Formatting (conform.nvim) | ⬜     |
| 20  | `plugins/editor/lint.lua`        | Linting (nvim-lint)       | ⬜     |
| 21  | `plugins/lang/*.lua`             | Language-specific configs | ⬜     |
| 22  | DAP/Debugging                    | Debug adapter protocol    | ⬜     |

---

## Decisions Log

| Date       | Decision                         | Rationale                                         |
| ---------- | -------------------------------- | ------------------------------------------------- |
| 2026-02-04 | Karabiner survives the nuke      | Config is clean, Hyper key is foundational        |
| 2026-02-04 | tmux + yabai are parallel layers | Macro (yabai) vs micro (tmux) spatial management  |
| 2026-02-04 | tmux prefix = `<C-Space>`        | Keeps `<C-a>` for shell, `<C-b>` for nvim page-up |
| 2026-02-04 | kanagawa as colorscheme          | Japanese ink aesthetic, warm and muted            |
| 2026-02-04 | MariaDB replaces PostgreSQL      | Reflects actual production stack                  |
| 2026-02-06 | Neovim Phase 1 complete          | Core is rock-solid, zero plugin deps              |
| 2026-02-06 | Ghostty config finalized         | Minimal, Neovim-optimized, tmux-ready             |

---

## Validation Checklist

```
:checkhealth                          # General health
:checkhealth lazy                     # Plugin manager
:checkhealth lsp                      # LSP (Phase 2+)
nvim --startuptime /tmp/s.log         # Must be < 50ms
grep -r "require.*plugin" lua/core/   # Must be empty
```

---

_PDE Rebuild — February 2026 | M4 Max · HHKB Type-S · Neovim 0.11.x_
