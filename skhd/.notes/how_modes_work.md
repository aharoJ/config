# 🧠 SKHD Modes — Simple Guide

## What’s really happening

- **skhd** can only read **one config file**, located at
  `~/.config/skhd/skhdrc`.

- Instead of editing that file every time, we made it a **shortcut (symlink)** that points to one of two real files:
  - `~/.config/skhd/modes/stack.skhd`
  - `~/.config/skhd/modes/bsp.skhd`

- When you run `yp -P stack` or `yp -P bsp`, the command:
  1. Switches **Yabai** to the same layout.
  2. Updates the `skhdrc` shortcut to point at the matching mode.
  3. Reloads skhd so the new hotkeys work instantly.

That’s why it looks like “magic.”
We’re not reloading two configs — we’re just flipping which one `skhdrc` points to.

---

## 💻 Commands you’ll actually use

| Action               | Command         |
| -------------------- | --------------- |
| Switch to stack mode | `yp -P stack`   |
| Switch to bsp mode   | `yp -P bsp`     |
| Check what’s active  | `yp --status`   |
| Reload skhd manually | `skhd --reload` |

---

## 🪄 Check or repair if something breaks

**See what file `skhdrc` is pointing at:**

```bash
readlink ~/.config/skhd/skhdrc
```

**Manually switch to stack mode:**

```bash
ln -sf ~/.config/skhd/modes/stack.skhd ~/.config/skhd/skhdrc && skhd --reload
```

**Manually switch to bsp mode:**

```bash
ln -sf ~/.config/skhd/modes/bsp.skhd ~/.config/skhd/skhdrc && skhd --reload
```

You should always see something like:

```
~/.config/skhd/skhdrc -> ~/.config/skhd/modes/bsp.skhd
```

---

## 🧩 How to verify everything’s synced

```bash
yp --status
```

This shows:

- Current **Yabai layout**
- **Window gap**
- Which file `skhdrc` points to
- Active mode name (`stack` or `bsp`)

---

## 🚀 Optional: Add more modes later

You can expand the system anytime.

Example:

1. Create `~/.config/yabai/scripts/profiles/float.sh`
2. Create `~/.config/skhd/modes/float.skhd`
3. Add a new `case float` inside your `yp` script
   (same logic as stack/bsp)

Now you’ve got **three modes**, all switchable in one command.

---

## 🧱 TL;DR

> skhd reads one file.
> `yp` just changes which file that is, then reloads skhd.
> It’s not magic — it’s a pointer swap.

