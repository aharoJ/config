#!/usr/bin/env bash
# path: ~/.config/skhd/scripts/stack-picker.sh
# description: fzf-powered stack inventory — shows all windows in the current
#              space, select one to focus. Runs inside a tmux popup so it
#              inherits your terminal theme and fzf styling.
# usage: bash ~/.config/skhd/scripts/stack-picker.sh
# date: 2026-03-13

set -euo pipefail

# ── Query windows in current space ────────────────────────────────────────
# Format: "window_id  app_name  title (truncated)"
# The focused window is marked with * for visual reference.

pick=$(yabai -m query --windows --space \
  | jq -r '
    [.[] | select(.["is-minimized"] == false)]
    | to_entries[]
    | "\(.value.id)  \(if .value["has-focus"] then "*" else " " end) \(.value.app)  \(.value.title[0:60])"
  ' \
  | fzf \
    --style full:line \
    --layout reverse \
    --highlight-line \
    --no-scrollbar \
    --ghost '  type to filter...' \
    --prompt '   ' \
    --pointer '▸' \
    --info inline-right \
    --input-label ' Search ' \
    --list-label ' Stack ' \
    --padding 1,2 \
    --bind 'ctrl-j:down,ctrl-k:up' \
    --bind 'result:transform-list-label:
      if [ -z $FZF_QUERY ]; then
        echo " $FZF_MATCH_COUNT windows ";
      else
        echo " $FZF_MATCH_COUNT matches ";
      fi' \
    --color 'fg:#c0caf5,fg+:#c0caf5,bg+:#283457,hl:#7aa2f7,hl+:#7aa2f7' \
    --color 'header:#565f89,prompt:#7aa2f7,pointer:#7aa2f7,marker:#9ece6a' \
    --color 'border:#414868,preview-border:#414868,label:#565f89' \
    --color 'list-border:#414868,list-label:#7aa2f7' \
    --color 'input-border:#414868,input-label:#7aa2f7' \
    --color 'info:#565f89' \
    --color 'ghost:#565f89' \
  || true)

# ── Focus selected window ────────────────────────────────────────────────
if [[ -n "$pick" ]]; then
  window_id=$(echo "$pick" | awk '{print $1}')
  yabai -m window --focus "$window_id"
fi
