#!/bin/sh
# ── copy-paths.sh ──────────────────────────────────────────────────
# path: ~/.config/yazi/scripts/copy-paths.sh
# Copy full paths of selected items to macOS clipboard (pbcopy).
# One absolute path per line.
#
# Usage (called by yazi keymap):
#   copy-paths.sh [file_or_dir ...]
#
# Environment:
#   YAZI_HOVERED  if set and no args, used before $PWD fallback
# ───────────────────────────────────────────────────────────────────

set -eu

# ── Fallback chain: selected → hovered → CWD ─────────────────────
if [ $# -eq 0 ]; then
  if [ -n "${YAZI_HOVERED:-}" ]; then
    set -- "$YAZI_HOVERED"
  else
    set -- "$PWD"
  fi
fi

# ── Copy ──────────────────────────────────────────────────────────
printf '%s\n' "$@" | pbcopy

# ── Feedback ──────────────────────────────────────────────────────
count=$#
if [ "$count" -eq 1 ]; then
  printf '📋 Copied path: %s\n' "$1" >&2
else
  printf '📋 Copied %d paths\n' "$count" >&2
fi
