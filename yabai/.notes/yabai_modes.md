### **File:** `~/.config/yabai/.notes/yabai_modes.md`

````markdown
# 🧠 Yabai Manual Mode Switcher — Notes

## What this does

This setup lets me **manually switch Yabai tiling modes** between `stack` and `bsp`  
instead of letting yabai auto-detect layouts.  
Each mode has its own clean `.sh` config file for padding, gap, and balance preferences.

Everything runs through one command:

```bash
yp -P stack    # stack layout
yp -P bsp      # bsp layout
```
````

---

## 🧩 How it works

### 1. Fish function (`yp.fish`)

- Lives at: `~/.config/fish/internal/yabai/yp.fish`
- Handles argument parsing and applies the correct mode script.
- Uses Yabai CLI (`yabai -m config ...`) to set padding/gaps.
- Prints a short summary after switching so I can confirm the active layout + window gap.

### 2. Mode profiles

- Stored in: `~/.config/yabai/scripts/profiles/`
- Each mode (like `stack.sh` or `bsp.sh`) contains:
  - Padding (top/bottom/left/right)
  - Window gap
  - `auto_balance` toggle
  - Split ratio

### 3. Base `yabairc`

- Keeps a **neutral default** (bsp layout, zero padding)
- Doesn’t override my mode switcher
- Only contains base rules and app exceptions (Finder, System Settings, etc.)

---

## 🧱 Modes

### stack

Used when working on the **MacBook** or smaller displays.
Keeps windows layered vertically with zero gap.

```bash
yabai -m config layout stack
yabai -m config window_gap 0
yabai -m config auto_balance off
```

### bsp

Used for **ultrawide / main monitor** setups.
Uses binary space partitioning for even splits.

```bash
yabai -m config layout bsp
yabai -m config window_gap 10
yabai -m config auto_balance on
```

---

## 🧩 Why I did this

- Auto profile switching was **unreliable** when moving between displays.
- Manual control (`yp -P`) gives **deterministic layouts** every time.
- Mimics my `sbr -P` Spring Boot runner style — simple and predictable.
- Helps me maintain consistent workspace feel across hardware.

---

## 🪄 Quick reference

| Command                          | Description              |                      |
| -------------------------------- | ------------------------ | -------------------- |
| `yp -P stack`                    | Apply MacBook/stack mode |                      |
| `yp -P bsp`                      | Apply ultrawide/bsp mode |                      |
| `yabai -m query --spaces --space | jq -r '.type'`           | Check current layout |
| `yabai --restart-service`        | Reload yabai daemon      |                      |

---

### ✅ Summary

This is a **manual, profile-based mode switcher** for Yabai.
Keeps the base config neutral, moves layout logic to external scripts,
and provides a consistent visual environment with one-line control.

> Think of it like: `sbr` but for window management.

