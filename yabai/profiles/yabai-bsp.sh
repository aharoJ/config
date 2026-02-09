#!/usr/bin/env sh
# path: ~/.config/yabai/profiles/yabai-bsp.sh
# description: BSP tiling — binary space partitioning with breathing room.
#              Windows automatically split and tile. Best for: multi-window
#              workflows, Ghostty + Vivaldi + Slack side-by-side.
# usage: bash ~/.config/yabai/profiles/yabai-bsp.sh
# date: 2026-02-08
# CHANGELOG: 2026-02-08 | Absorbed BSP-specific settings from yabairc:
#              window_placement, split_type, window_insertion_point,
#              insert_feedback_color. These are tree concepts that only
#              apply to BSP layout — they were polluting the neutral base.
#            ROLLBACK: Move these 4 settings back to yabairc if needed.

# ── Layout ──────────────────────────────────────────────────────
yabai -m config layout                       bsp

# ── BSP Tree Behavior ───────────────────────────────────────────

# WHY second_child: New windows appear right/below, matching natural reading flow.
yabai -m config window_placement             second_child

# WHY auto: yabai picks vertical or horizontal split based on window dimensions.
# Wide windows split vertically, tall windows split horizontally. v7 feature.
yabai -m config split_type                   auto

# WHY focused: New windows split at the focused window, not the tree root.
# More intuitive — the split happens where your eyes already are.
yabai -m config window_insertion_point        focused

# WHY warm red: Visual hint showing where a new window will land in BSP tree.
# Visible without being distracting. Only appears during insertion.
yabai -m config insert_feedback_color        0xffd75f5f

# ── Padding & Gaps ──────────────────────────────────────────────
# WHY 8: Small breathing room between windows. Enough to visually separate
# without wasting screen real estate on the M4 Max display.
# ADJUST: Change all values to 0 for zero-gap, or 12-16 for more aesthetic spacing.
yabai -m config top_padding                  8
yabai -m config bottom_padding               8
yabai -m config left_padding                 8
yabai -m config right_padding                8
yabai -m config window_gap                   8

# ── Balance ─────────────────────────────────────────────────────
# WHY on: When windows open/close, auto-rebalance so every window gets equal space.
# Prevents the "one huge window, three tiny ones" problem.
yabai -m config auto_balance                 on
yabai -m config split_ratio                  0.50

# ── Post-Apply: Rebalance Existing Windows ──────────────────────
# WHY: If switching from stack→bsp, existing windows may have stale split ratios.
yabai -m space --balance 2>/dev/null || true

echo "yabai profile: bsp (8px gaps, auto-balanced)"
