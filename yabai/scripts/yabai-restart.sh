#!/usr/bin/env bash
# path: ~/.config/yabai/scripts/yabai-restart.sh
# description: Restart yabai cleanly and apply a layout profile.
#              Replaces the old ~/.scripts/yabai-restart-clean.sh.
#              No scripting addition, no Hammerspoon, no skhd symlink swapping.
# usage: bash ~/.config/yabai/scripts/yabai-restart.sh [stack|bsp|float]
# date: 2026-02-07

set -euo pipefail

PROFILE="${1:-stack}"
PROFILES_DIR="${HOME}/.config/yabai/profiles"
PROFILE_SCRIPT="${PROFILES_DIR}/yabai-${PROFILE}.sh"

# ── Validate Profile ────────────────────────────────────────────
if [[ ! -f "$PROFILE_SCRIPT" ]]; then
  echo "error: unknown profile '${PROFILE}'" >&2
  echo "available: $(ls "${PROFILES_DIR}"/yabai-*.sh 2>/dev/null | sed 's|.*/yabai-||;s|\.sh||' | tr '\n' ' ')" >&2
  exit 1
fi

# ── Restart Service ─────────────────────────────────────────────
# WHY --restart-service: Atomic stop+start handled by launchd.
# If yabai isn't running, fall back to --start-service.
if yabai -m query --displays &>/dev/null 2>&1; then
  yabai --restart-service
else
  yabai --start-service
fi

# ── Wait for Ready ──────────────────────────────────────────────
# WHY: yabai needs a moment after service restart to bind its socket.
# Poll up to 3 seconds (60 × 50ms). If it doesn't come up, bail.
for _ in $(seq 1 60); do
  yabai -m query --displays &>/dev/null 2>&1 && break
  sleep 0.05
done

if ! yabai -m query --displays &>/dev/null 2>&1; then
  echo "error: yabai did not start within 3 seconds" >&2
  echo "check: tail -f /tmp/yabai_${USER}.err.log" >&2
  exit 1
fi

# ── Apply Profile ───────────────────────────────────────────────
bash "$PROFILE_SCRIPT"

# ── Ghostty Retile Fix ─────────────────────────────────────────
# WHY: Ghostty sometimes doesn't retile properly after yabai restart.
# Toggle float twice forces yabai to recalculate the window geometry.
# This is a known workaround. Safe to remove if Ghostty fixes this upstream.
if command -v jq &>/dev/null; then
  ghostty_ids=$(yabai -m query --windows | jq -r '.[] | select(.app=="Ghostty") | .id' 2>/dev/null || true)
  for id in $ghostty_ids; do
    yabai -m window "$id" --toggle float 2>/dev/null || true
    yabai -m window "$id" --toggle float 2>/dev/null || true
  done
fi

echo "yabai-restart: done (profile=${PROFILE})"
