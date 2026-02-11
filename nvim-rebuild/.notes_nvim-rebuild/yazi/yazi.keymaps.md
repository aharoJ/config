# Yazi Keymap Reference

> keymap.toml delta-only architecture — only overrides and additions, defaults inherited.

## Clipboard (`c` prefix)

| Key | Action | Notes |
|-----|--------|-------|
| `cc` | Copy contents to clipboard | External script, recursive, headers, prunes junk dirs |
| `ct` | Copy tree to clipboard | External script, eza --tree, no icons |
| `cp` | Copy file path | Remapped from default `cc` |
| `cf` | Copy filename | Default (unchanged) |
| `cn` | Copy filename (no ext) | Default (unchanged) |
| `Y` | Copy raw file contents | Quick cat, no headers, no recursion |
| `cd` | Disabled | Redundant — use `cp` |

**Scripts:** `~/.config/yazi/scripts/copy-contents.sh` and `copy-tree.sh`
- Operate on **selected** items (Space/v to select)
- Fallback: hovered → CWD
- Prune: `.git`, `node_modules`, `.next`, `target`, `build`, `dist`, `__pycache__`, `.gradle`, `.idea`, `.vscode`
- Size guard: files >1MB skipped

## Navigation (`g` prefix)

| Key | Action |
|-----|--------|
| `gg` | Top of list (default) |
| `G` | Bottom of list (default) |
| `gh` | cd ~ (default) |
| `g/` | cd / (default) |
| `gtc` | cd ~/.config |
| `gtd` | cd ~/Downloads |
| `gtr` | cd ~/.repository |
| `gtw` | cd ~/.westernu |
| `gc` | Disabled — use `gtc` |
| `gd` | Disabled — use `gtd` |

## Open (`o` prefix)

| Key | Action |
|-----|--------|
| `owp` | Open with picker (interactive) |
| `owc` | Open in VS Code |
| `owv` | Open in Neovim |
| `owm` | Open in Modern CSV |
| `owf` | Reveal in Finder |
| `ott` | New tmux tab at CWD |

## Overrides

| Key | Action | Why |
|-----|--------|-----|
| `q` | Quit (no cd) | Swapped with Q |
| `Q` | Quit + cd to CWD | Swapped with q |
| `Esc` / `C-[` / `C-c` | Escape all | Clears visual, selection, filter, search, find |
| `Enter` | Open hovered only | Prevents accidental multi-open |
| `Space` | Toggle select (no advance) | Cursor stays put |

## File Operations (defaults, untouched)

| Key | Action |
|-----|--------|
| `y` | Yank (mark for copy) |
| `Y` | ~~Unyank~~ → remapped to copy/raw |
| `x` | Cut (mark for move) |
| `p` | Paste yanked/cut files |
| `d` | Trash / delete |
| `r` | Rename |
| `a` | Create file |
| `A` | Create directory |
