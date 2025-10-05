#!/usr/bin/env bash
# ~/.config/tmux/scripts/sysline.sh
# Prints: CPU 21% · RAM 24.7G/36.0G (macOS-aligned)

set -euo pipefail

TOP=/usr/bin/top
VMSTAT=/usr/bin/vm_stat
SYSCTL=/usr/sbin/sysctl
AWK=/usr/bin/awk

# ----- CPU: user% + sys% from `top` (matches Activity Monitor) -----
cpu_pct="$($TOP -l 1 -n 0 | $AWK '/CPU usage/ {
  n=0;
  for (i=1; i<=NF; i++) {
    if ($i ~ /%$/) { gsub("%","",$i); vals[++n]=$i; }
  }
  # vals[1] = user, vals[2] = sys
  printf("%.0f", (n>=2 ? vals[1] + vals[2] : 0));
  exit
}')"

# ----- RAM: Total − (Free + Cached Files) -----
# Cached Files ≈ File-backed + Speculative pages
eval "$($VMSTAT | $AWK '
  /page size of/        {ps=$8}
  /Pages free/          {gsub("\\.","",$3); fr=$3}
  /File-backed pages/   {gsub("\\.","",$3); fb=$3}
  /Pages speculative/   {gsub("\\.","",$3); sp=$3}
  END {
    if (fb=="") fb=0; if (sp=="") sp=0;
    printf "pagesize=%s; free=%s; fileback=%s; speculative=%s;\n", ps, fr, fb, sp
  }
')"

total_bytes="$($SYSCTL -n hw.memsize)"
cached_pages=$(( fileback + speculative ))
used_bytes=$(( total_bytes - (free + cached_pages) * pagesize ))

# GiB with 1 decimal
used_g=$(printf '%.1f' "$(echo "$used_bytes / 1073741824" | bc -l)")
total_g=$(printf '%.1f' "$(echo "$total_bytes / 1073741824" | bc -l)")

printf 'CPU %s%% · RAM %sG/%sG\n' "$cpu_pct" "$used_g" "$total_g"
