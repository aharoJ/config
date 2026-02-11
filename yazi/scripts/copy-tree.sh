#!/bin/sh
# ── copy-tree.sh ────────────────────────────────────────────────────
# path: ~/.config/yazi/scripts/copy-tree.sh
# Copy file tree structure of selected items to macOS clipboard.
# The complement to copy-contents.sh: copies the MAP, not the code.
# Uses eza --tree for beautiful box-drawing output.
#
# Usage (called by yazi keymap):
#   copy-tree.sh [file_or_dir ...]
#
# Output format:
#   src
#   ├── main.ts
#   └── lib
#      ├── types.ts
#      └── utils.ts
#
# Dependencies: eza (brew install eza)
#
# Environment:
#   YAZI_HOVERED  if set and no args, used before $PWD fallback
# ────────────────────────────────────────────────────────────────────

set -eu

# ── Pruned directories (single source of truth) ────────────────────
# Pipe-delimited for eza's -I flag. Mirror changes in copy-contents.sh.
IGNORE=".git|node_modules|.next|.svelte-kit|target|build|dist|__pycache__|.gradle|.idea|.vscode"

# ── Fallback chain: selected → hovered → CWD ───────────────────────
if [ $# -eq 0 ]; then
  if [ -n "${YAZI_HOVERED:-}" ]; then
    set -- "$YAZI_HOVERED"
  else
    set -- "$PWD"
  fi
fi

# ── Collect ─────────────────────────────────────────────────────────
{
  for item in "$@"; do
    if [ -f "$item" ]; then
      basename "$item"
    elif [ -d "$item" ]; then
      eza --tree --icons=never --no-permissions --no-user --no-time --no-filesize -I "$IGNORE" "$item"
    fi
  done
} | pbcopy

# ── Feedback ────────────────────────────────────────────────────────
count=$#
if [ "$count" -eq 1 ]; then
  printf '🗂️  Copied tree: %s\n' "$(basename "$1")" >&2
else
  printf '🗂️  Copied tree of %d items\n' "$count" >&2
fi
