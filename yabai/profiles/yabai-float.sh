#!/usr/bin/env sh
# path: ~/.config/yabai/profiles/yabai-float.sh
# description: Float mode — yabai steps back, macOS native windowing takes over.
#              Windows are freely positionable. Yabai still handles float rules
#              and focus keybinds, but no automatic tiling or stacking.
#              Best for: presentations, screen sharing, casual use.
# usage: bash ~/.config/yabai/profiles/yabai-float.sh
# date: 2026-02-07

# ── Layout ──────────────────────────────────────────────────────
yabai -m config layout                       float

# ── Padding & Gaps ──────────────────────────────────────────────
# WHY 0: Float mode = macOS native. No tiling padding needed.
yabai -m config top_padding                  0
yabai -m config bottom_padding               0
yabai -m config left_padding                 0
yabai -m config right_padding                0
yabai -m config window_gap                   0

# ── Balance ─────────────────────────────────────────────────────
yabai -m config auto_balance                 off
yabai -m config split_ratio                  0.50

echo "yabai profile: float (native macOS windowing)"
