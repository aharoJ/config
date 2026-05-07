#!/usr/bin/env bash
# ~/.config/tmux/scripts/sysline.sh
# Prints: CPU 21% · RAM 24.7G/36.0G (macOS-aligned)

set -euo pipefail

PS=/bin/ps
VMSTAT=/usr/bin/vm_stat
SYSCTL=/usr/sbin/sysctl
AWK=/usr/bin/awk

# ----- CPU: normalized ps sum (10ms, reacts to load; iostat -c 1 is since-boot avg) -----
cpu_count="${STAGE_CPU_COUNT:-$($SYSCTL -n hw.logicalcpu)}"
cpu_pct="$($PS -A -o %cpu= | $AWK -v n="$cpu_count" '
  {s+=$1} END {p=s/n; if(p>100)p=100; printf "%.0f", p}
')"

# ----- RAM: Total − (Free + Cached Files) -----
# Cached Files ≈ File-backed + Speculative pages
# hw.memsize never changes; honour a pre-exported STAGE_MEM_TOTAL to skip the sysctl fork.
total_bytes="${STAGE_MEM_TOTAL:-$($SYSCTL -n hw.memsize)}"

read -r used_g total_g < <($VMSTAT | $AWK -v total="$total_bytes" '
  /page size of/        {ps=$8}
  /Pages free/          {gsub("\\.","",$3); fr=$3}
  /File-backed pages/   {gsub("\\.","",$3); fb=$3}
  /Pages speculative/   {gsub("\\.","",$3); sp=$3}
  END {
    if (fb=="") fb=0; if (sp=="") sp=0;
    used = total - (fr + fb + sp) * ps
    printf "%.1f %.1f\n", used/1073741824, total/1073741824
  }
')

printf 'CPU %s%% · RAM %sG/%sG\n' "$cpu_pct" "$used_g" "$total_g"
