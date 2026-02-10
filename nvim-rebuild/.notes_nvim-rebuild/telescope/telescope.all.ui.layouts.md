# Telescope Layout Variations — Reference Guide

> A living document for cataloging every telescope.nvim layout configuration worth keeping.
> Swap any of these into your opts table and restart nvim.

---

## How This Works

Telescope has **3 layers** you can mix and match to create layouts:

| Layer               | What It Controls                      | Options                                                                          |
| ------------------- | ------------------------------------- | -------------------------------------------------------------------------------- |
| **Layout Strategy** | Window arrangement                    | `horizontal`, `vertical`, `center`, `cursor`, `flex`, `bottom_pane`              |
| **Layout Config**   | Sizing, positioning, behavior         | `width`, `height`, `anchor`, `mirror`, `prompt_position`, `preview_width/height` |
| **Themes**          | Presets that bundle strategy + config | `get_dropdown()`, `get_ivy()`, `get_cursor()`                                    |

On top of that, you can tweak **cosmetics** independently: `borderchars`, `winblend`, `prompt_prefix`, `selection_caret`, `path_display`, `border`, titles, etc.

The total combination space is massive — what follows are 30 distinct layout variations, plus cosmetic modifiers that multiply the possibilities even further.

---

## ⚠️ Gotchas & Bugs (Learned the Hard Way)

### `previewer = true` is BROKEN — do NOT use it
Telescope expects the `previewer` field to be either `false` (to disable) or an actual **previewer object**. Setting `previewer = true` passes a boolean where telescope expects a table, and it **silently fails** — no error, no preview, no warning.

- **Want preview OFF?** → `previewer = false`
- **Want preview ON?** → **Omit the field entirely** (it's on by default)

This is a confirmed bug (GitHub issue #2101).

### `preview_cutoff` silently kills your preview
The vertical layout has a default `preview_cutoff` of ~30 **lines**. If your terminal doesn't have enough lines, telescope quietly drops the preview pane. No error.

**Fix:** Always add `preview_cutoff = 1` to any layout that uses preview. This means "only hide preview if the terminal is literally 1 line tall."

```lua
layout_config = {
    preview_height = 0.4,
    preview_cutoff = 1,  -- ALWAYS include this for layouts with preview
},
```

Horizontal layouts have the same option but measured in **columns** instead of lines.

### `preview_height` / `preview_width` are RELATIVE to the picker, not the screen
These are **percentages of the picker's total height/width**, not the screen.

```
Screen
 └─ height (total picker size, e.g. 0.8 = 80% of screen)
     ├─ prompt (fixed ~1 line)
     ├─ results (whatever's left)
     └─ preview_height (share of the picker, e.g. 0.4 = 40% of the picker)
```

So `height = 0.2` + `preview_height = 0.8` = preview is 80% of 20% = **16% of screen**. If you want a big preview, you need a big `height` first.

### Theme wrappers are unnecessary if you're customizing everything
`get_ivy()`, `get_dropdown()`, `get_cursor()` are just convenience functions that set `layout_strategy` + `layout_config` + some cosmetics. Since you're hand-crafting everything anyway, skip them entirely and use raw config tables. This avoids the function vs table type-check issue and keeps everything consistent.

### `pcall` the fzf extension load
If the native C build fails, `load_extension("fzf")` will error and break your entire config. Always wrap it:
```lua
pcall(require("telescope").load_extension, "fzf")
```

---

## Favorites (Starred)

#### New Finds

9 → pretty dope for debugging potentially
10 → same as above but cleaner
12 → super minimal but just go big

16 → super clean / best for knowing the exact file with ff
19 → best for debugging
26 → has potential
27 → looks fancy af
28 → potential
30 → central potential

### ⭐ #8 — Vertical Mirrored

```
┌────────────────────────────┐
│          Prompt            │
├────────────────────────────┤
│          Results           │
│                            │
├────────────────────────────┤
│          Preview           │
│                            │
└────────────────────────────┘
```

```lua
local opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.6,
        height = 0.9,
        preview_height = 0.45,
        preview_cutoff = 1,
        prompt_position = "top",
        mirror = true,
    },
}
```

### ⭐ #14 — Ivy Minimal

Same as `bottom_pane` strategy with no preview. Docked to bottom of screen.

```
════════════════════════════════════════════
│ Prompt                                   │
├──────────────────────────────────────────┤
│ Results                                  │
════════════════════════════════════════════
```

```lua
local opts = {
    previewer = false,
    layout_strategy = "bottom_pane",
    layout_config = {
        height = 0.3,
        prompt_position = "top",
    },
}
```

### ⭐ #18 — Ultra Minimal (No Preview, No Borders)

```
        ┌──────────────────────┐
        │       Prompt         │
        ├──────────────────────┤
        │       Results        │
        └──────────────────────┘
```

```lua
local opts = {
    previewer = false,
    layout_strategy = "center",
    border = false,
    layout_config = {
        width = 0.4,
        height = 0.35,
    },
}
```

---

## All Variations

### Horizontal Family (#1–#6)

#### 1 — Horizontal Classic

```
┌─────────────────┐┌─────────────────┐
│     Results      ││     Preview     │
│                  ││                 │
└─────────────────┘│                 │
┌─────────────────┐│                 │
│     Prompt       ││                 │
└─────────────────┘└─────────────────┘
```

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.8,
        height = 0.8,
        preview_width = 0.55,
        preview_cutoff = 1,
        prompt_position = "bottom",
    },
}
```

#### 2 — Horizontal Mirrored (Preview Left, Prompt Top)

```
┌─────────────────┐┌─────────────────┐
│                  ││     Prompt      │
│     Preview      │├─────────────────┤
│                  ││     Results     │
│                  ││                 │
└─────────────────┘└─────────────────┘
```

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.85,
        height = 0.85,
        preview_width = 0.5,
        preview_cutoff = 1,
        prompt_position = "top",
        mirror = true,
    },
}
```

#### 3 — Horizontal Wide (Thin Results, Huge Preview)

```
┌────────┐┌───────────────────────────────┐
│Results ││          Preview              │
│        ││                               │
├────────┤│                               │
│Prompt  ││                               │
└────────┘└───────────────────────────────┘
```

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.95,
        height = 0.85,
        preview_width = 0.7,
        preview_cutoff = 1,
        prompt_position = "bottom",
    },
}
```

#### 4 — Horizontal No Preview (File List Only)

```lua
local opts = {
    previewer = false,
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.5,
        height = 0.6,
        prompt_position = "top",
    },
}
```

#### 5 — Full-Screen Horizontal (IDE Mode)

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.99,
        height = 0.99,
        preview_width = 0.6,
        preview_cutoff = 1,
        prompt_position = "top",
    },
}
```

#### 6 — Padding-Based Sizing (Edge-to-Edge With Margin)

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = { padding = 3 },
        height = { padding = 2 },
        preview_width = 0.55,
        preview_cutoff = 1,
        prompt_position = "top",
    },
}
```

---

### Vertical Family (#7–#11)

#### 7 — Vertical Stacked (Preview Top)

```
┌────────────────────────────┐
│          Preview           │
│                            │
├────────────────────────────┤
│          Results           │
│                            │
├────────────────────────────┤
│          Prompt            │
└────────────────────────────┘
```

```lua
local opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.6,
        height = 0.9,
        preview_height = 0.5,
        preview_cutoff = 1,
        prompt_position = "bottom",
        mirror = false,
    },
}
```

#### ⭐ 8 — Vertical Mirrored (Prompt Top, Preview Bottom)

_See Favorites above._

#### 9 — Full-Screen Vertical

```lua
local opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.99,
        height = 0.99,
        preview_height = 0.6,
        preview_cutoff = 1,
        prompt_position = "top",
        mirror = true,
    },
}
```

#### 10 — Vertical Compact (Small Preview)

```lua
local opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.5,
        height = 0.7,
        preview_height = 0.25,
        preview_cutoff = 1,
        prompt_position = "top",
        mirror = true,
    },
}
```

#### 11 — Vertical No Preview (Tall List)

```lua
local opts = {
    previewer = false,
    layout_strategy = "vertical",
    layout_config = {
        width = 0.4,
        height = 0.8,
        prompt_position = "top",
    },
}
```

---

### Ivy / Bottom Pane Family (#12–#16)

#### 12 — Ivy With Preview

```
════════════════════════════════════════════
│ Prompt                                   │
├────────────────────┬─────────────────────┤
│ Results            │ Preview             │
│                    │                     │
════════════════════════════════════════════
```

```lua
local opts = {
    layout_strategy = "bottom_pane",
    layout_config = {
        height = 0.4,
        preview_cutoff = 1,
        prompt_position = "top",
    },
}
```

#### 13 — Ivy Tall (Half Screen)

```lua
local opts = {
    layout_strategy = "bottom_pane",
    layout_config = {
        height = 0.55,
        preview_cutoff = 1,
        prompt_position = "top",
    },
}
```

#### ⭐ 14 — Ivy Minimal (No Preview)

_See Favorites above._

#### 15 — Bottom Pane

```
┌──────────────────────────────────────────┐
│                 (editor)                 │
├──────────┬───────────────────────────────┤
│ Prompt   │ Preview                       │
├──────────┤                               │
│ Results  │                               │
└──────────┴───────────────────────────────┘
```

```lua
local opts = {
    layout_strategy = "bottom_pane",
    layout_config = {
        height = 25,
        preview_cutoff = 1,
        prompt_position = "top",
    },
}
```

#### 16 — Bottom Pane No Preview

```lua
local opts = {
    previewer = false,
    layout_strategy = "bottom_pane",
    layout_config = {
        height = 15,
        prompt_position = "top",
    },
}
```

---

### Dropdown / Center Family (#17–#20)

#### 17 — Dropdown (No Preview)

```
        ┌──────────────────────┐
        │       Prompt         │
        ├──────────────────────┤
        │       Results        │
        │       Results        │
        │       Results        │
        └──────────────────────┘
```

```lua
local opts = {
    previewer = false,
    layout_strategy = "center",
    layout_config = {
        width = 0.5,
        height = 0.4,
    },
}
```

#### ⭐ 18 — Ultra Minimal Center (No Preview, No Borders)

_See Favorites above._

#### 19 — Dropdown With Preview

```lua
local opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.6,
        height = 0.6,
        preview_height = 0.4,
        preview_cutoff = 1,
        prompt_position = "top",
        mirror = true,
    },
}
```

#### 20 — Tiny Centered Dropdown (Command Palette Style)

```lua
local opts = {
    previewer = false,
    layout_strategy = "center",
    layout_config = {
        width = 0.35,
        height = 0.25,
        anchor = "N",
    },
}
```

---

### Cursor Family (#21–#22)

#### 21 — Cursor With Preview

```
  █ (cursor)
  ┌──────────────┐┌─────────────────┐
  │   Prompt     ││    Preview      │
  ├──────────────┤│                 │
  │   Results    ││                 │
  └──────────────┘└─────────────────┘
```

```lua
local opts = {
    layout_strategy = "cursor",
    layout_config = {
        width = 0.7,
        height = 0.4,
        preview_cutoff = 1,
    },
}
```

#### 22 — Cursor Minimal

```lua
local opts = {
    previewer = false,
    layout_strategy = "cursor",
    layout_config = {
        width = 0.4,
        height = 0.3,
    },
}
```

---

### Adaptive (#23)

#### 23 — Flex (Auto Horizontal ↔ Vertical)

Switches based on window width.

```lua
local opts = {
    layout_strategy = "flex",
    layout_config = {
        width = 0.8,
        height = 0.85,
        flip_columns = 130,
        horizontal = { preview_width = 0.55, preview_cutoff = 1 },
        vertical = { preview_height = 0.45, preview_cutoff = 1 },
    },
}
```

---

### Anchored Positions (#24–#30)

#### 24 — Anchored Top-Right Corner

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.6,
        height = 0.5,
        anchor = "NE",
        prompt_position = "top",
        preview_width = 0.5,
        preview_cutoff = 1,
    },
}
```

#### 25 — Anchored Bottom-Left

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.5,
        height = 0.4,
        anchor = "SW",
        prompt_position = "top",
        preview_width = 0.5,
        preview_cutoff = 1,
    },
}
```

#### 26 — Anchored Top-Center (Notification Style)

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.7,
        height = 0.35,
        anchor = "N",
        prompt_position = "top",
        preview_width = 0.5,
        preview_cutoff = 1,
    },
}
```

#### 27 — Anchored Bottom-Center

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.7,
        height = 0.35,
        anchor = "S",
        prompt_position = "top",
        preview_width = 0.5,
        preview_cutoff = 1,
    },
}
```

#### 28 — Tall Narrow Sidebar (Anchored East)

```lua
local opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.35,
        height = 0.9,
        anchor = "E",
        prompt_position = "top",
        mirror = true,
        preview_height = 0.4,
        preview_cutoff = 1,
    },
}
```

#### 29 — Tall Narrow Sidebar (Anchored West)

```lua
local opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.35,
        height = 0.9,
        anchor = "W",
        prompt_position = "top",
        mirror = true,
        preview_height = 0.4,
        preview_cutoff = 1,
    },
}
```

#### 30 — Fixed Pixel Sizes (Exact Control)

```lua
local opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 120,
        height = 30,
        preview_width = 60,
        preview_cutoff = 1,
        prompt_position = "top",
    },
}
```

---

## Cosmetic Modifiers

These can be added to **any** variation above to change the look further.

### Transparency

```lua
winblend = 15,  -- 0 = opaque, 100 = fully transparent
```

### Custom Border Characters

```lua
-- rounded (default-ish)
borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },

-- sharp corners
borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },

-- double line
borderchars = { "═", "║", "═", "║", "╔", "╗", "╝", "╚" },

-- thick
borderchars = { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗" },

-- minimal dots
borderchars = { "·", "│", "·", "│", "·", "·", "·", "·" },

-- empty (border spacing without visible lines)
borderchars = { " ", " ", " ", " ", " ", " ", " ", " " },

-- dashes
borderchars = { "╌", "╎", "╌", "╎", "┌", "┐", "┘", "└" },
```

### Prompt Icons

```lua
prompt_prefix = "  ",     -- magnifying glass
prompt_prefix = "  ",     -- arrow
prompt_prefix = " > ",      -- classic
prompt_prefix = "  ",     -- lambda
prompt_prefix = " ❯ ",      -- chevron
prompt_prefix = "  ",     -- telescope
prompt_prefix = " 🔎 ",     -- emoji search
```

### Selection Carets

```lua
selection_caret = "  ",    -- arrow
selection_caret = " ▸ ",     -- triangle
selection_caret = " ● ",     -- dot
selection_caret = " ┃ ",     -- bar
selection_caret = " ❯ ",     -- chevron
selection_caret = " → ",     -- arrow
```

### Path Display

```lua
-- just the filename
path_display = { "tail" },

-- shortened directories
path_display = { shorten = { len = 1, exclude = { -1 } } },

-- filename first, then path
path_display = { "filename_first" },

-- filename first, reversed directory order
path_display = {
    filename_first = {
        reverse_directories = true,
    },
},

-- truncate long paths
path_display = { "truncate" },
path_display = { truncate = 3 },

-- completely hidden
path_display = { "hidden" },

-- smart (removes common prefix)
path_display = { "smart" },
```

### Titles

```lua
-- custom titles
prompt_title = "Find File",
results_title = "Matches",

-- hide titles entirely
prompt_title = false,
results_title = false,
```

### Preview Hidden on Start

```lua
preview = {
    hide_on_startup = true,  -- toggle with actions.layout.toggle_preview
},
```

---

## Anchor Reference

All 9 anchor positions for pinning the picker to screen edges:

```
 NW ──── N ──── NE
 │                │
 W    CENTER     E
 │                │
 SW ──── S ──── SE
```

```lua
anchor = "NW"     -- top-left corner
anchor = "N"      -- top-center
anchor = "NE"     -- top-right corner
anchor = "W"      -- left-center
anchor = ""       -- center (default)
anchor = "E"      -- right-center
anchor = "SW"     -- bottom-left corner
anchor = "S"      -- bottom-center
anchor = "SE"     -- bottom-right corner
```

---

## Sizing Reference

Width and height accept multiple formats:

```lua
-- percentage of screen (0 < n < 1)
width = 0.8         -- 80% of screen

-- fixed character count (n >= 1)
width = 120         -- exactly 120 columns

-- padding from edges
width = { padding = 5 }   -- screen width minus 10 (5 each side)

-- percentage with min/max constraints
width = { 0.8, min = 80 }
height = { 0.6, max = 40 }

-- function (maximum flexibility)
width = function(_, max_columns, _)
    return math.min(max_columns - 10, 140)
end
```

---

## Layout Strategy Quick Reference

| Strategy      | Best For                      | Key Options                               |
| ------------- | ----------------------------- | ----------------------------------------- |
| `horizontal`  | Wide screens, side-by-side    | `preview_width`, `mirror`, `preview_cutoff` (columns) |
| `vertical`    | Narrow screens, stacked       | `preview_height`, `mirror`, `preview_cutoff` (lines)  |
| `center`      | Dropdown menus, compact lists | `preview_cutoff` (lines)                  |
| `cursor`      | Context-aware popups          | appears at cursor position                |
| `flex`        | Responsive layouts            | `flip_columns`, `flip_lines`              |
| `bottom_pane` | IDE-style panels              | docked to bottom edge                     |

---

## Composing Your Own

Take any strategy + config + cosmetics and combine:

```lua
local my_opts = {
    -- STRATEGY
    layout_strategy = "vertical",

    -- CONFIG
    layout_config = {
        width = 0.5,
        height = 0.8,
        preview_height = 0.4,
        preview_cutoff = 1,
        prompt_position = "top",
        mirror = true,
        anchor = "E",
    },

    -- COSMETICS
    border = true,
    borderchars = { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗" },
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    prompt_title = "Find File",
    results_title = false,
    path_display = { "filename_first" },
    sorting_strategy = "ascending",
}
```

---

## Notes

- **Never use `previewer = true`** — it's a boolean where telescope expects a table/nil. Omit the field entirely for preview ON, use `previewer = false` for preview OFF.
- **Always add `preview_cutoff = 1`** to any layout that uses preview. The default cutoff silently hides preview on smaller terminals.
- **`preview_height` / `preview_width` are relative** to the picker's total size, not the screen.
- **Skip theme wrappers** (`get_dropdown`, `get_ivy`, `get_cursor`) — they add indirection. Use raw config tables for consistency.
- **`mirror`** flips the position of results/prompt relative to preview.
- **`prompt_position`** only accepts `"top"` or `"bottom"`.
- Anchor + small size = floating palette anywhere on screen.
- You can combine `winblend` with any layout for a translucent look.
- The `create_layout` API exists for fully custom window arrangements (raw nvim window API) but is overkill for most use cases.
- **`pcall` the fzf extension load** — if the native build fails, it breaks your whole config.
