#!/usr/bin/env sh
# path: ~/.config/yabai/profiles/yabai-stack.sh
# description: Stack mode — one focused window at a time, maximized.
#              All windows share the same space, cycle with stack.next/prev.
#              Best for: deep focus, single-task workflow, large monitors.
# usage: bash ~/.config/yabai/profiles/yabai-stack.sh
# date: 2026-02-07

# ── Layout ──────────────────────────────────────────────────────
yabai -m config layout                       stack

# ── Padding & Gaps ──────────────────────────────────────────────
yabai -m config top_padding                  20
yabai -m config bottom_padding               20
yabai -m config left_padding                 20
yabai -m config right_padding                20
yabai -m config window_gap                   0


# ── Balance ─────────────────────────────────────────────────────
# WHY off: Balance is meaningless in stack mode (no splits to balance).
yabai -m config auto_balance                 off
yabai -m config split_ratio                  0.50

echo "yabai profile: stack (0 gaps, maximized)"
