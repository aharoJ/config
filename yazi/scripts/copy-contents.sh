#!/bin/sh
# ── copy-contents.sh ────────────────────────────────────────────────
# path: ~/.config/yazi/scripts/copy-contents.sh
# Copy file contents of selected items to macOS clipboard (pbcopy).
# Handles files, directories, and mixed selections.
#
# Usage (called by yazi keymap):
#   copy-contents.sh [file_or_dir ...]
#
# Behavior:
#   - Files:       header + contents
#   - Directories: recursive find (excludes hidden files, junk dirs)
#   - No args:     falls back to $YAZI_HOVERED, then $PWD
#
# Headers use paths relative to each item root:
#   ~~~ src/main.ts ~~~
#   ~~~ lib/utils.ts ~~~
#
# Environment:
#   YAZI_HOVERED  if set and no args, used before $PWD fallback
#
# Exit codes:
#   0  success (contents copied to clipboard)
#   1  no readable files found
# ────────────────────────────────────────────────────────────────────

set -eu

# ── Size guard ──────────────────────────────────────────────────────
# Skip files larger than ~1MB to protect clipboard from binary blobs.
# WHY -1024k not -1M: GNU find rounds -1M up, making it miss small files.
# -1024k is portable across GNU (Linux) and BSD (macOS) find.
MAX_SIZE="1024k"

# ── Fallback chain: selected → hovered → CWD ───────────────────────
if [ $# -eq 0 ]; then
  if [ -n "${YAZI_HOVERED:-}" ]; then
    set -- "$YAZI_HOVERED"
  else
    set -- "$PWD"
  fi
fi

# ── Helpers ─────────────────────────────────────────────────────────

emit_file() {
  # $1 = absolute path, $2 = display path (relative header)
  [ -r "$1" ] || return 0
  printf '~~~ %s ~~~\n' "$2"
  cat "$1"
  printf '\n'
}

find_in_dir() {
  # Recursive find with pruned junk dirs, hidden files excluded, size-capped.
  # Each pruned dir is explicit — no regex, no variables, grep-able at 3 AM.
  find "$1" \
    -type d \( \
    -name ".git" \
    -o -name "node_modules" \
    -o -name ".next" \
    -o -name ".svelte-kit" \
    -o -name "target" \
    -o -name "build" \
    -o -name "dist" \
    -o -name "__pycache__" \
    -o -name ".gradle" \
    -o -name ".idea" \
    -o -name ".vscode" \
    \) -prune \
    -o -type f \
    -not -name ".*" \
    -size "-${MAX_SIZE}" \
    -print |
    LC_ALL=C sort
}

process_item() {
  item="$1"

  if [ -f "$item" ]; then
    emit_file "$item" "$(basename "$item")"

  elif [ -d "$item" ]; then
    find_in_dir "$item" | while IFS= read -r f; do
      # Strip root prefix → clean relative path for header
      rel="${f#"$item"}"
      rel="${rel#/}"
      emit_file "$f" "$rel"
    done
  fi
  # Symlinks, sockets, pipes: silently ignored — intentional
}

# ── Main ────────────────────────────────────────────────────────────
{
  for item in "$@"; do
    process_item "$item"
  done
} | pbcopy

# ── Feedback (stderr so it doesn't pollute clipboard) ───────────────
count=$#
if [ "$count" -eq 1 ]; then
  printf '📋 Copied contents: %s\n' "$(basename "$1")" >&2
else
  printf '📋 Copied contents of %d items\n' "$count" >&2
fi
