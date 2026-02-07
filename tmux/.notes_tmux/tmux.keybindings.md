# tmux Keybindings

> Prefix = `C-b` (pressed as `Cmd+z` via Ghostty)

---

## Navigation

| Keys  | Action                                               |
| ----- | ---------------------------------------------------- |
| `C-h` | Move focus left (nvim split OR tmux pane — seamless) |
| `C-j` | Move focus down                                      |
| `C-k` | Move focus up                                        |
| `C-l` | Move focus right                                     |

> These are in the **root table** — no prefix needed. If the pane is running Neovim, the key is forwarded to Neovim instead.

---

## Pane Splitting

| Keys          | Action                        |
| ------------- | ----------------------------- |
| `prefix + \|` | Vertical split (side by side) |
| `prefix + -`  | Horizontal split (top/bottom) |

> Both open in the current working directory.

---

## Pane Management

| Keys         | Action                              |
| ------------ | ----------------------------------- |
| `prefix + c` | Kill pane (c = close)               |
| `prefix + z` | Toggle zoom (fullscreen ↔ restore) |
| `prefix + X` | Kill window                         |

---

## Pane Resizing

| Keys         | Action                 |
| ------------ | ---------------------- |
| `prefix + H` | Resize left (5 cells)  |
| `prefix + J` | Resize down (5 cells)  |
| `prefix + K` | Resize up (5 cells)    |
| `prefix + L` | Resize right (5 cells) |

> Repeatable — hold prefix, tap multiple times.

---

## Window (Tab) Navigation

| Keys           | Action                       |
| -------------- | ---------------------------- |
| `prefix + t`   | New window (in current path) |
| `prefix + [`   | Previous window              |
| `prefix + ]`   | Next window                  |
| `prefix + 1-9` | Jump to window by number     |
| `prefix + <`   | Move window left in list     |
| `prefix + >`   | Move window right in list    |

---

## Session Management

| Keys         | Action              |
| ------------ | ------------------- |
| `prefix + ,` | Rename session      |
| `prefix + s` | Session tree picker |
| `prefix + (` | Previous session    |
| `prefix + )` | Next session        |
| `prefix + d` | Detach from tmux    |

---

## Copy Mode

| Keys         | Action                            |
| ------------ | --------------------------------- |
| `prefix + v` | Enter copy mode                   |
| `v`          | Start selection                   |
| `C-v`        | Toggle rectangle selection        |
| `y`          | Yank selection → system clipboard |
| `Escape`     | Exit copy mode                    |

> Paste with `Cmd+V` — OSC 52 sends yanks to system clipboard automatically.

> Copy mode uses vi keybindings — `hjkl`, `/` search, `n/N` next/prev match, `gg/G` top/bottom.

---

## Utility

| Keys         | Action                                   |
| ------------ | ---------------------------------------- |
| `prefix + r` | Reload config                            |
| `prefix + ?` | List all keybindings                     |
| `prefix + :` | Command prompt                           |
| `prefix + q` | Show pane numbers (press number to jump) |

---

## Mental Model

```
lowercase hjkl  →  navigate (C-hjkl root, prefix+hjkl default)
UPPERCASE HJKL  →  resize   (prefix+HJKL)
[ / ]           →  prev / next window (bracket stepping)
t               →  new tab (window)
c               →  close pane
v               →  copy mode (visual)
|               →  vertical split (visual: looks like a divider)
-               →  horizontal split (visual: looks like a separator)
z               →  zoom
,               →  rename session
```
