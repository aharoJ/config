#!/usr/bin/env bash
# Prints: CPU 12% · RAM 8.2G/36.0G  (macOS-safe)

set -euo pipefail

# --- CPU (% of total cores) ---
ncpu=$(sysctl -n hw.ncpu)
cpu_pct=$(ps -A -o %cpu= | awk -v n="$ncpu" '
  { s += $1 }
  END {
    p = s / n
    if (p < 0) p = 0
    if (p > 100) p = 100
    printf("%.0f", p)
  }')

# --- RAM (used/MAX in GiB) ---
mem_bytes=$(sysctl -n hw.memsize)
free_pct=$(memory_pressure -Q 2>/dev/null | awk -F': *' '/System-wide memory free percentage/ {gsub("%","",$2); print $2; exit}')

if [[ -n "${free_pct:-}" ]]; then
  # Use memory_pressure when available (newer macOS)
  used_bytes=$(awk -v m="$mem_bytes" -v f="$free_pct" 'BEGIN{printf "%.0f", (100-f)/100*m}')
else
  # Fallback: vm_stat
  pagesize=$(vm_stat | awk '/page size of/ {print $8}')
  # strip trailing dots in counts
  parse() { vm_stat | awk -v k="$1" '$0 ~ k {gsub("\\.","",$3); print $3; exit}'; }
  free=$(parse "Pages free")
  speculative=$(parse "Pages speculative")
  inactive=$(parse "Pages inactive")
  active=$(parse "Pages active")
  wired=$(parse "Pages wired")
  # Rough "used" = active + inactive + wired (exclude free+speculative)
  used_pages=$(( active + inactive + wired ))
  used_bytes=$(( used_pages * pagesize ))
fi

used_g=$(awk -v b="$used_bytes" 'BEGIN{printf "%.1f", b/1073741824}')
total_g=$(awk -v b="$mem_bytes"  'BEGIN{printf "%.1f", b/1073741824}')

printf "CPU %s%% · RAM %sG/%sG" "$cpu_pct" "$used_g" "$total_g"
