# ⌨️ Karabiner-Elements — Audit & Reference

> The keyboard firmware layer. Sits below everything — transforms physical key events before any app sees them.
> **Status:** ✅ Done. Survived the nuke. No changes needed.

---

## Hyper Key

Hyper = `Cmd + Ctrl + Opt + Shift` fired simultaneously. Lives on **two** physical keys:

| Physical Key | Tap    | Hold  |
| ------------ | ------ | ----- |
| **Escape**   | Escape | Hyper |
| **CapsLock** | —      | Hyper |

---

## Active Rules

| Rule                      | What It Does                | Status  |
| ------------------------- | --------------------------- | ------- |
| Escape → Hyper / Esc      | Primary Hyper trigger       | ✅ Keep |
| CapsLock → Hyper          | Redundant Hyper trigger     | ✅ Keep |
| Hyper + 1–9 → Ctrl+1–9    | macOS desktop switching     | ✅ Keep |
| Hyper + [ ] → Ctrl+←→     | Desktop prev/next           | ✅ Keep |
| Hyper + F1/F2 → backlight | Keyboard illumination       | ✅ Keep |
| Both Shifts → CapsLock    | Toggle caps lock            | ✅ Keep |
| Sysdiagnose blockers      | Block Hyper+,/./slash crash | ✅ Keep |
| Mouse speed → 100         | Scroll speed boost          | I love  |

---

## HHKB Hardware

- **SW2 ON** — left Diamond (◇) becomes Fn
- Bottom row: `Fn` · `Alt/Opt` · `Cmd` · `Space` · `Cmd` · `Alt/Opt`
- Ctrl is home-row left (where CapsLock normally lives)

---

## Known Conflict

Karabiner owns `Hyper + [ ]` for desktop switching. skhd also binds `Hyper + [ ]` for yabai stack focus. **Karabiner wins** (fires first) — skhd brackets are dead code. `Hyper + j/k` covers stack focus, so no functionality lost. Clean up skhd when it's rebuilt.

---

## Future Considerations

- After tmux is configured: verify Ghostty passes `<C-Space>` cleanly (Ghostty config, not Karabiner)
- If Karabiner is disabled, Neovim and tmux must still work with native keys — no hard dependencies

---

# 🎹 Keybinding Namespace Map

> Every modifier combo assigned to exactly one tool. Zero collisions.

| Modifier              | Owner        | Purpose               | Notes                     |
| --------------------- | ------------ | --------------------- | ------------------------- |
| `Hyper + 1-9`         | Karabiner    | Desktop 1–9           | Fires as Ctrl+N           |
| `Hyper + [ ]`         | Karabiner    | Desktop prev/next     | Fires as Ctrl+arrows      |
| `Hyper + F1/F2`       | Karabiner    | Keyboard backlight    | HHKB-specific             |
| `Hyper + letter`      | skhd → yabai | Window management     | j/k/r/x/y/z/e/d/b/g       |
| `rshift + letter`     | skhd         | App launchers         | v/g/f/d/k                 |
| `shift + alt + key`   | skhd         | Gentle yabai actions  | rotate, border, etc.      |
| `ctrl + alt + arrows` | skhd         | Move window to space  |                           |
| `<C-Space> + key`     | tmux         | Multiplexer commands  | Prefix mode               |
| `<C-h/j/k/l>`         | tmux + nvim  | Pane/split navigation | Navigator plugin resolves |
| `<C-d/u>`             | Neovim       | Half-page scroll      | tmux passes through       |
| `<M-h/j/k/l>`         | Neovim       | Window resize         | Meta is nvim-exclusive    |
| `<leader> + key`      | Neovim       | Editor commands       | Space bar, nvim-only      |

---

_PDE Rebuild — February 2026_
