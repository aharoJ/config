# Yabai PDE Rebuild — Complete Reference Guide

_February 2026 · yabai 7.1.x · macOS 26.2 Tahoe · M4 Max · SIP Enabled_

---

## How This Started

The yabai rebuild was part of a larger PDE (Personalized Development Environment) rebuild where every tool gets nuked and rebuilt from scratch. The guiding principle: "top 0.1% craftsmanship — every line earns its place."

The old yabai config had ~400 lines of commented-out graveyard code, references to tools that no longer exist (Alacritty, kitty, Übersicht, sketchybar), dead scripting addition calls that never worked because SIP was enabled, and deprecated v6/v7 options that silently did nothing. It was a config that grew by accretion over years without ever being questioned.

The rebuild started from the official yabai wiki and CHANGELOG, not from the old config. The goal was to discover features that were being missed entirely — the same way the tmux rebuild revealed that splits and panes had never been explored.

---

## The Three Spatial Layers

This is the foundational mental model for the entire PDE. Three tools manage three layers of spatial organization, operating in parallel — never competing:

```
┌─── macOS Desktop (yabai) ──────────────────────────────────────────┐
│  Which APPLICATION goes where on which space/display.              │
│  yabai manages: Ghostty, browser, Slack, Finder positions.        │
│                                                                    │
│  ┌─── Ghostty Window ──────────────────────────────────────────┐  │
│  │  ┌─── tmux session: "webapp" ──────────────────────────┐    │  │
│  │  │  What's happening INSIDE the terminal.               │    │  │
│  │  │  tmux manages: sessions, windows, panes.             │    │  │
│  │  │                                                      │    │  │
│  │  │  ┌─── tmux pane ─────┐ ┌─── tmux pane ─────┐       │    │  │
│  │  │  │                   │ │                     │       │    │  │
│  │  │  │  Neovim           │ │  shell / lazygit   │       │    │  │
│  │  │  │  (splits/buffers) │ │  / test runner     │       │    │  │
│  │  │  │                   │ │                     │       │    │  │
│  │  │  └───────────────────┘ └─────────────────────┘       │    │  │
│  │  └──────────────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌─── Browser ──────┐ ┌─── Slack ───────────────────────┐        │
│  └──────────────────┘ └─────────────────────────────────┘        │
└────────────────────────────────────────────────────────────────────┘
```

**yabai** = macro layer (which macOS window goes where)
**tmux** = micro layer (sessions/panes inside Ghostty)
**Neovim** = inner layer (splits/buffers inside one tmux pane)

Each tool does ONE job. No overlap. No redundancy.

---

## Deep Research: yabai 7.x From Ground Truth

### Sources Consulted

- Official yabai wiki (Configuration page, Commands page)
- yabai.asciidoc (canonical reference for all config options)
- CHANGELOG.md (complete v5 → v6 → v7 migration path)
- GitHub issues (#1863 SIP feature matrix, #2203 scratchpads, #2128 sub-layer rename, #2510 window_insertion_point, #2479 split_type reclassification)
- Official example yabairc (koekeishiya/yabai/master/examples/yabairc)
- Community configs (rafi, Josh Medeski, linkarzu)

### What Was Removed in v6/v7 (Dead Code in Old Config)

| Feature                         | Removed In         | What Happened                                                 |
| ------------------------------- | ------------------ | ------------------------------------------------------------- |
| `window_border`                 | v6 (macOS Ventura) | Apple changed window compositing. Use JankyBorders if needed. |
| `window_topmost`                | v6                 | Related to border removal.                                    |
| `window_opacity_duration`       | v6                 | Animation control removed with compositor changes.            |
| `application_activated` signal  | v6                 | Replaced by `window_focused` signal.                          |
| `layer` in rules                | v7                 | Renamed to `sub-layer`.                                       |
| `--toggle border` skhd bindings | v6                 | All border toggling is dead code.                             |

### SIP Status: Enabled (No Scripting Addition)

SIP is fully enabled on the M4 Max. This is a deliberate choice — the scripting addition had compatibility issues on macOS Tahoe, and the features it unlocks aren't worth the maintenance burden for this workflow.

**Available without SA (everything we need):**

- Layout modes: `bsp`, `stack`, `float`
- Window operations: `focus`, `swap`, `warp`, `resize`, `zoom`, `float toggle`
- Padding, gaps, auto-balance, split ratio
- BSP tree behavior: `split_type`, `window_placement`, `window_insertion_point`, `insert_feedback_color`
- Mouse management (modifier + drag, `mouse_drop_action`)
- Window rules (float rules, manage=off, sub-layer, grid)
- Signals (event-driven automation)
- Scratchpads (named floating windows)
- `window_zoom_persist`, `display_arrangement_order`, `window_origin_display`
- `windowed-fullscreen` toggle
- `menubar_opacity`, `external_bar`

**SIP-gated (silently ignored with SIP enabled):**

- `window_shadow` — shadow control requires scripting addition
- `window_opacity`, `active_window_opacity`, `normal_window_opacity` — transparency requires scripting addition
- `window_animation_duration > 0.0` — also requires Screen Recording permission
- `window_animation_easing` — no-op while animations are disabled/SIP-gated
- `yabai -m space --focus` (focusing a different space)
- `yabai -m window --space` (moving windows across spaces)
- Creating/destroying spaces beyond macOS's 16-space limit

These SIP-gated settings are kept in yabairc with honest comments acknowledging they're no-ops. They serve as future-proofing documentation — if SIP is ever partially disabled, the values are ready. Same principle as Spring Boot explicitly declaring `server.port=8080`.

**Space switching workaround:** Karabiner-Elements Hyper+1-9 fires Ctrl+N for native macOS space switching. More reliable than the scripting addition on Tahoe anyway.

### v7 Features Discovered During Rebuild

These are features that existed in yabai 7.x but the old config never utilized:

**split_type auto** (reclassified to space setting in v7.1.6) — yabai decides vertical vs horizontal split based on available space dimensions. Smarter than always splitting one direction. Now lives in BSP profile.

**window_insertion_point focused** (new in v7.1.6, #2510) — New windows split at the focused window, not the tree root. More intuitive — the split happens where your eyes already are. BSP-only concept, lives in BSP profile.

**insert_feedback_color** — Visual color hint showing where a new window will be inserted in BSP mode. Subtle but helpful spatial feedback. BSP profile.

**window_zoom_persist** — When you zoom a window and focus another, the zoom state persists when you come back. Without this, zoom resets on focus change. Layout-agnostic, lives in neutral base.

**mouse_drop_action** — Controls what happens when you drag a window onto another: `swap` (exchange positions) or `stack` (create a stack from two windows).

**Scratchpads** — Named floating windows toggled with one key. Like i3's scratchpad.

```sh
yabai -m rule --add app="Ghostty" title="dropdown" scratchpad="term" grid="6:6:1:1:4:4"
yabai -m window --toggle term  # brings it to active space or hides it
```

**windowed-fullscreen** — Fullscreen that ignores ALL padding. Different from `zoom-fullscreen` which respects gaps.

**Stack numeric indices** — `yabai -m window --focus stack.3` to jump to the 3rd window in a stack directly, not just cycling prev/next.

**Space labels** — `yabai -m space 1 --label code` then reference by name. Named workspaces.

**--ratio** — Resize windows to exact ratios: `yabai -m window --ratio abs:0.66` for a 2/3 split.

**Signals** — Event-driven automation hooks. The old config had dead signal code. Properly used signals enable auto-refocus when windows close and auto-restart on display changes.

**rule --apply** — v7 requirement. Without this at the end of yabairc, float rules only apply to windows opened AFTER yabai starts. With `--apply`, rules retroactively hit windows that already exist.

**Ghostty subrole rule** — Ghostty's quick terminal feature spawns windows with `subrole="AXFloatingWindow"`. Adding a rule prevents yabai from tiling it.

---

## The Architecture: Inversion of Control (IoC)

### The Pattern

The yabai architecture follows an Inversion of Control pattern, inspired by Spring Boot's dependency injection.

**Traditional approach (old config):** yabairc does EVERYTHING — sets layout, padding, gaps, rules, signals, mouse behavior. Want to change layouts? Edit yabairc, change multiple lines, restart. The config IS the controller.

**IoC approach (new config):** yabairc is a neutral container. It sets only global behavior that applies regardless of layout mode. Layout decisions are INJECTED from outside — by profile scripts that run after boot.

```
yabairc (the "container"):
  → sets ONLY global behavior (rules, signals, mouse)
  → does NOT decide layout, padding, gaps, or tree behavior
  → hands off layout decisions to whatever profile is injected

profiles/ (the "beans" / "components"):
  → yabai-stack.sh declares: "I am stack. 20px inset. 0 gaps."
  → yabai-bsp.sh declares: "I am BSP. 8px gaps. Auto-balance. Tree behavior."
  → yabai-float.sh declares: "I am float. No tiling."

yabai-restart.sh (the "container runtime"):
  → starts yabai (runs yabairc → neutral base)
  → INJECTS the selected profile on top
```

### The Spring Boot Analogy

| Spring Boot                            | yabai PDE                                          |
| -------------------------------------- | -------------------------------------------------- |
| `ApplicationContext` (container)       | `yabairc` (neutral base)                           |
| `@Bean` / `@Component`                 | `yabai-stack.sh`, `yabai-bsp.sh`, `yabai-float.sh` |
| `@Profile("dev")` / `@Profile("prod")` | `yr -P stack` / `yr -P bsp`                        |
| Container calls your beans at runtime  | `yabai-restart.sh` sources the selected profile    |

The key insight: yabairc doesn't KNOW or CARE whether it's running stack or BSP. It provides the infrastructure (signals, rules, mouse settings). The profile injects the specific behavior at runtime. That's why you can hot-swap with `yp bsp` without touching yabairc — the container stays stable, only the injected component changes.

### Neutral Base — True Layout Agnosticism

yabairc sets NO layout. If you boot yabai without running a profile, you get yabai's built-in default: `float` (no tiling, raw macOS). You always explicitly kick off your day with `yr -P stack`, so the neutral base is the cleaner pattern. If the profile script ever breaks, you fix it — you don't silently fall back to a layout that might not be what you want.

### What Lives Where (The Separation of Concerns)

```
SETTING                      WHERE              WHY
─────────────────────────────────────────────────────────────────
window_zoom_persist          yabairc            Layout-agnostic behavior
mouse_follows_focus          yabairc            Layout-agnostic behavior
focus_follows_mouse          yabairc            Layout-agnostic behavior
mouse_modifier/action1/2     yabairc            Layout-agnostic input
mouse_drop_action            yabairc            Layout-agnostic input
window_origin_display        yabairc            Layout-agnostic display
display_arrangement_order    yabairc            Layout-agnostic display
external_bar                 yabairc            Layout-agnostic bar
menubar_opacity              yabairc            Layout-agnostic bar
window_shadow                yabairc            SIP-gated, layout-agnostic
window_opacity/*             yabairc            SIP-gated, layout-agnostic
window_animation_*           yabairc            SIP-gated, layout-agnostic
All float rules              yabairc            Apply regardless of layout
All signals                  yabairc            Apply regardless of layout
rule --apply                 yabairc            v7 retroactive application

layout                       profiles/*         THE layout decision
top/bottom/left/right_padding profiles/*        Layout-specific spacing
window_gap                   profiles/*         Layout-specific spacing
auto_balance                 profiles/*         Layout-specific behavior
split_ratio                  profiles/*         Layout-specific behavior
window_placement             yabai-bsp.sh       BSP tree concept only
split_type                   yabai-bsp.sh       BSP tree concept only (v7.1.6 space setting)
window_insertion_point       yabai-bsp.sh       BSP tree concept only (v7.1.6)
insert_feedback_color        yabai-bsp.sh       BSP tree concept only
yabai -m space --balance     yabai-bsp.sh       BSP rebalance on profile switch
```

### Why Each Profile Declares Its COMPLETE State

`yabai-stack.sh` sets layout, padding, gaps, auto_balance, and split_ratio. `yabai-bsp.sh` does the same plus BSP-specific tree settings. Even though some values overlap, each profile is self-contained.

Why: if you switch from BSP back to stack, `yabai-stack.sh` must reset EVERYTHING BSP changed. If it only set the values that differ from defaults, switching profiles would leave orphaned BSP settings (like `auto_balance on`) bleeding into stack mode.

Each profile is idempotent — run it from any state and you get exactly that mode. No ordering dependencies, no assumptions about what was set before.

---

## The Three Layout Modes

### BSP (Binary Space Partitioning)

The signature yabai mode. Windows tile by recursively splitting the screen into halves. Open 3 windows and you get one on the left, two stacked on the right. Every window is visible simultaneously.

Best for: side-by-side coding, comparing files, reference material next to editor.

Profile settings: `layout bsp`, 8px gaps, `auto_balance on`, `split_ratio 0.50`, plus BSP tree behavior (`window_placement second_child`, `split_type auto`, `window_insertion_point focused`, `insert_feedback_color`).

### Stack

All windows in a space occupy the same full area, layered like a deck of cards. Only one is visible at a time. Cycle through them with `yabai -m window --focus stack.next/prev`.

Best for: single-monitor deep focus, presentations, full-screen workflow where you cycle between apps without overlap.

Profile settings: `layout stack`, 20px padding for visual breathing room, 0 gaps (one window visible), `auto_balance off`, `split_ratio 0.50`.

Important: stack mode needs refocus signals. If you close the top card, yabai must auto-focus the next one or you're staring at your desktop. This is handled by signals in yabairc (layout-agnostic, but critical for stack):

```sh
yabai -m signal --add event=window_destroyed  active=yes action="yabai -m query --windows --window &> /dev/null || yabai -m window --focus recent"
yabai -m signal --add event=window_minimized  active=yes action="yabai -m window --focus recent"
yabai -m signal --add event=application_hidden active=yes action="yabai -m window --focus recent"
```

### Float

yabai hands off completely. No automatic tiling. Windows behave like vanilla macOS: drag, resize, overlap.

Best for: video calls, design tools, situations where tiling fights you.

Profile settings: `layout float`, 0 padding, 0 gaps, `auto_balance off`, `split_ratio 0.50`.

---

## File Structure

```
~/.config/yabai/
├── yabairc                          # Neutral base — globals, rules, signals, mouse (NO layout)
├── profiles/
│   ├── yabai-stack.sh               # Stack: one window, 20px inset, 0 gaps
│   ├── yabai-bsp.sh                 # BSP: tiled, 8px gaps, auto-balance, tree behavior
│   └── yabai-float.sh               # Float: native macOS windowing
└── scripts/
    └── yabai-restart.sh             # Clean restart + profile injection

~/.config/fish/internal/yabai/
├── yr.fish                          # Restart + profile apply (yr -P stack)
├── ys.fish                          # Start yabai service
├── yk.fish                          # Stop yabai service
└── yp.fish                          # Hot-swap profile WITHOUT restart
```

### yabairc — The Neutral Container

Contains ONLY:

- Global behavior (mouse, zoom persist, focus follows mouse)
- SIP-gated settings with honest no-op comments (shadow, opacity, animation)
- Explicit non-SIP defaults (external_bar, menubar_opacity)
- Float rules (apps that should never be tiled: System Settings, Calculator, etc.)
- Ghostty-specific rules (AXFloatingWindow subrole for quick terminal)
- Signals (refocus on window destroy, display change auto-restart)
- `yabai -m rule --apply` at the end (v7 retroactive rule application)

Does NOT contain: layout, padding, gaps, auto_balance, split_ratio, or any BSP tree settings (window_placement, split_type, window_insertion_point, insert_feedback_color). Those are profile territory.

### Profiles — The Injected Components

Each profile is a standalone shell script that sets layout-specific values. Completely idempotent — run from any state, get exactly that mode.

**yabai-stack.sh:**

```sh
yabai -m config layout         stack
yabai -m config top_padding    20
yabai -m config bottom_padding 20
yabai -m config left_padding   20
yabai -m config right_padding  20
yabai -m config window_gap     0
yabai -m config auto_balance   off
yabai -m config split_ratio    0.50
```

**yabai-bsp.sh:**

```sh
yabai -m config layout                   bsp
# BSP tree behavior
yabai -m config window_placement         second_child
yabai -m config split_type               auto
yabai -m config window_insertion_point   focused
yabai -m config insert_feedback_color    0xffd75f5f
# Padding & gaps
yabai -m config top_padding              8
yabai -m config bottom_padding           8
yabai -m config left_padding             8
yabai -m config right_padding            8
yabai -m config window_gap               8
# Balance
yabai -m config auto_balance             on
yabai -m config split_ratio              0.50
# Post-apply rebalance
yabai -m space --balance 2>/dev/null || true
```

**yabai-float.sh:**

```sh
yabai -m config layout         float
yabai -m config top_padding    0
yabai -m config bottom_padding 0
yabai -m config left_padding   0
yabai -m config right_padding  0
yabai -m config window_gap     0
yabai -m config auto_balance   off
yabai -m config split_ratio    0.50
```

### yabai-restart.sh — The Container Runtime

Orchestrates the full restart + profile injection sequence:

1. Validates the requested profile exists (defaults to `stack`)
2. Restarts yabai service (`--restart-service`, atomic — not stop+sleep+start)
3. Waits for yabai socket to be ready (60 × 50ms polling, 3-second timeout)
4. Sources the selected profile script
5. Applies the Ghostty float-toggle workaround (double-toggle forces Ghostty to respect new padding)

The wait-for-ready loop is critical — without it, profile commands fire before yabai's IPC socket is listening, and every `yabai -m config` silently fails.

### Ghostty Float-Toggle Workaround

Ghostty windows sometimes ignore padding changes after a yabai restart. The fix: toggle float twice on each Ghostty window:

```sh
yabai -m window "$id" --toggle float  # float it
yabai -m window "$id" --toggle float  # un-float it (now respects new padding)
```

This forces yabai to recalculate Ghostty's position within the new padding constraints. Safe to remove if Ghostty fixes this upstream.

---

## Fish Functions — The User Interface

### yr (yabai restart)

The primary command. Restarts yabai and applies a profile.

```fish
yr -P stack    # restart + apply stack profile
yr -P bsp      # restart + apply BSP profile
yr             # restart with default profile (stack)
```

Calls `~/.config/yabai/scripts/yabai-restart.sh` under the hood.

### yp (yabai profile — hot-swap)

Switches layout WITHOUT restarting yabai. Instant profile change.

```fish
yp bsp         # instantly switch to BSP
yp stack       # instantly switch back to stack
```

This is the IoC pattern in action — yabai is already running (container is up), you're just swapping which component is injected. No restart needed because profiles only call `yabai -m config` commands, which take effect immediately.

### ys / yk (start / stop)

Simple service management:

```fish
ys             # yabai --start-service
yk             # yabai --stop-service
```

---

## Boot Sequence

The daily workflow:

```
1. Login to macOS
2. Ghostty auto-launches (or you open it)
3. tmux sessions auto-attach (or you create them)
4. Run: yr -P stack
   → yabai-restart.sh executes
   → yabai service restarts
   → yabairc loads (neutral base: rules, signals, mouse)
   → wait for socket ready
   → yabai-stack.sh sources (layout=stack, 20px inset, 0 gaps)
   → Ghostty float-toggle workaround
   → Status output confirms stack mode
5. You're in stack mode. One app fills the screen.
   Hyper+J/K cycles through the stack.
   Need side-by-side? Run: yp bsp (instant switch, no restart)
   Need vanilla macOS? Run: yp float
```

---

## What Was Nuked From the Old Config

| Old Code                                                 | Why It Was Removed                                        |
| -------------------------------------------------------- | --------------------------------------------------------- |
| `sudo yabai --load-sa` + dock restart signal             | SIP fully enabled, scripting addition is dead code        |
| All `window_border` / `--toggle border` references       | Removed from yabai v6+ (macOS Ventura compositor changes) |
| `window_topmost`                                         | Removed from yabai v6+                                    |
| `ctrl + alt - left/right` space travel                   | Requires SA, replaced by Karabiner Hyper+1-9              |
| All Alacritty, kitty references                          | Different terminal, no longer in the stack                |
| All Übersicht, sketchybar references                     | Not in the toolchain                                      |
| All blur toggle scripts                                  | Required SA features that don't exist                     |
| ~400 lines of commented-out graveyard code               | Cargo-culted settings nobody understood                   |
| Multi-monitor/multi-display logic                        | Single monitor workflow                                   |
| skhd symlink swapping (modes/stack.skhd, modes/bsp.skhd) | Single unified skhdrc works for all layouts               |

---

## Key Architectural Decisions

### BSP Settings in BSP Profile (Not Neutral Base)

The February 8 refactor moved four BSP-specific settings out of yabairc into `yabai-bsp.sh`:

- `window_placement second_child` — BSP tree insertion direction
- `split_type auto` — BSP split orientation (reclassified to space setting in v7.1.6)
- `window_insertion_point focused` — BSP insertion target (new in v7.1.6, #2510)
- `insert_feedback_color 0xffd75f5f` — BSP insertion visual hint

These are all BSP tree concepts. In stack and float modes they're no-ops — they don't break anything, but housing them in the neutral base violated the IoC principle. The neutral base should have zero opinion on layout, including tree behavior.

### SIP-Gated Settings Kept With Honest Comments

Settings that require the scripting addition (shadow, opacity, animation) are kept in yabairc but grouped under a clearly labeled section acknowledging they're no-ops with SIP enabled. This serves two purposes: future-proofing if SIP is ever partially disabled, and documenting what yabai's default values are so a future version changing them won't cause surprises.

### Single skhdrc vs. Symlink Swapping

The old config had separate skhd files per layout mode, with a symlink swap during profile switches. The new architecture uses a single unified skhdrc. Why: yabai commands like `--focus`, `--swap`, and `--warp` adapt automatically to the current layout mode. The same keybinding works in both BSP and stack — yabai handles the context.

The `||` fallback pattern makes this work:

```sh
# This works in BOTH BSP and stack:
yabai -m window --focus west || yabai -m window --focus stack.prev
```

In BSP, `--focus west` succeeds (moves to the window on the left). In stack, it fails (no "west" in a stack), so the fallback `--focus stack.prev` fires instead.

### Explicit Profile Naming

Old: `stack.sh`, `bsp.sh`
New: `yabai-stack.sh`, `yabai-bsp.sh`, `yabai-float.sh`

Why: when you're grepping through configs at 3 AM, `yabai-stack.sh` is immediately identifiable. `stack.sh` could be anything.

### Display Change Signals

```sh
yabai -m signal --add event=display_added   action="yabai --restart-service"
yabai -m signal --add event=display_removed action="yabai --restart-service"
```

Auto-restarts yabai when monitors connect/disconnect. Without this, plugging in an external display requires manual intervention.

---

## Gemini Comparison (Honest Assessment)

During the rebuild, the same yabai config was independently generated by Gemini for comparison. Here's what each version got right:

**Gemini's wins (merged into final):**

- More comprehensive v7 config options (single IPC call pattern)
- Refocus signals on window destroy/minimize/hide
- Ghostty `AXFloatingWindow` subrole rule
- Scratchpad templates
- Inline WHY comments matching constitution style
- Docker Desktop / Karabiner float rules

**Claude's wins (kept in final):**

- Full IoC architecture (neutral base, profile injection)
- Complete deliverable set (10 files vs 4)
- Single skhdrc instead of symlink swapping
- Explicit `yabai-*.sh` naming per user's request
- Float profile (Gemini only had stack + BSP)
- Display change signals for auto-restart
- Atomic `--restart-service` instead of stop+sleep+start
- `yp.fish` hot-swap function (instant profile change without restart)
- BSP-specific settings correctly isolated in BSP profile

**Merged result:** Gemini's yabairc technical depth + Claude's architecture, naming, fish functions, and complete deliverable set.

---

## Expansion Opportunities

Things to explore in future iterations:

1. **Scratchpad workflow** — Configure named scratchpads for specific tools (quick terminal, calculator, music player). One hotkey to summon/dismiss.

2. **Space labels** — Name spaces semantically (`code`, `web`, `comms`) instead of numbering. Reference by name in scripts.

3. **Per-space profiles** — Different layouts on different spaces. Space 1 = BSP for coding, Space 2 = stack for browsing, Space 3 = float for calls.

4. **JankyBorders** — Since yabai dropped native borders, JankyBorders is the community replacement. Adds colored borders to the focused window.

5. **Signal-driven automation** — Auto-balance BSP on `window_created`, auto-label spaces based on which app is focused, auto-switch profiles based on time of day.

6. **Stack indicators** — Visual feedback showing position in the stack (2/5) and what's below. Previously handled by Hammerspoon, could be rebuilt with a simpler tool.

7. **Ratio-based layouts** — Use `--ratio abs:0.66` for asymmetric BSP splits (2/3 editor, 1/3 browser).

---

_This guide covers the complete yabai rebuild from research through architecture through implementation. The IoC pattern, three-layout system, and fish function interface are the foundation — everything else builds on top._

_Last updated: February 2026 · Post BSP-extraction refactor + SIP-honesty pass_
