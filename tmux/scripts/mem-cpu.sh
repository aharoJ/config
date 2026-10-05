#!/bin/sh
# path: ~/.config/tmux/scripts/mem-cpu.sh
# description: One-second CPU interval and approximate non-file-backed RAM in GiB.
# patched: Rounds 4–6: portable timeout discovery, repeated headings, numeric normalization.
# date: 2026-10-04

fallback='CPU ?% · RAM ?G/?G'
runner=
for candidate in /opt/homebrew/bin/timeout /opt/homebrew/bin/gtimeout /usr/local/bin/timeout /usr/local/bin/gtimeout; do
    if [ -x "$candidate" ]; then
        runner=$candidate
        break
    fi
done
if [ -z "$runner" ]; then
    printf '%s\n' "$fallback"
    exit 0
fi

result=$(/usr/bin/env -u ENV -u BASH_ENV LC_ALL=C PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    "$runner" --signal=KILL 2.5s /bin/sh -c '
    ram="?G/?G"
    cpu="?"
    if total=$(/usr/sbin/sysctl -n hw.memsize) && vm=$(/usr/bin/vm_stat); then
        ram=$(printf "%s\n" "$vm" | /usr/bin/awk -v total="$total" '\''
            /page size of/ {
                text=$0
                sub(/^.*page size of[[:space:]]*/, "", text)
                sub(/[[:space:]].*$/, "", text)
                page=text; pages++
            }
            /^[[:space:]]*Pages free:/ {
                text=$0; sub(/^[^:]*:[[:space:]]*/, "", text)
                sub(/[[:space:]]*$/, "", text)
                sub(/\.$/, "", text)
                free=text; frees++
            }
            /^[[:space:]]*File-backed pages:/ {
                text=$0; sub(/^[^:]*:[[:space:]]*/, "", text)
                sub(/[[:space:]]*$/, "", text)
                sub(/\.$/, "", text)
                file=text; files++
            }
            END {
                sub(/^[[:space:]]*/, "", total)
                sub(/[[:space:]]*$/, "", total)
                if (total !~ /^[0-9]+$/ || page !~ /^[0-9]+$/ || pages != 1 ||
                    free !~ /^[0-9]+$/ || frees != 1 ||
                    file !~ /^[0-9]+$/ || files != 1) {
                    print "?G/?G"; exit
                }
                total+=0; page+=0; free+=0; file+=0
                power=page
                while (power > 1 && power % 2 == 0) power/=2
                if (total <= 0 || page < 1024 || page > 1048576 || power != 1 ||
                    (free+file)*page > total || total/1073741824 > 9999.9) {
                    print "?G/?G"; exit
                }
                printf "%.1fG/%.1fG", (total-(free+file)*page)/1073741824, total/1073741824
            }
        '\'')
    fi
    if stats=$(/usr/sbin/iostat -C -n 0 -c 2 -w 1); then
        cpu=$(printf "%s\n" "$stats" | /usr/bin/awk '\''
            /(^|[[:space:]])us[[:space:]]+sy[[:space:]]+id([[:space:]]|$)/ {
                for (i=1; i<=NF; i++) if ($i=="us") column=i
                next
            }
            /^[[:space:]]*cpu([[:space:]]+load[[:space:]]+average)?[[:space:]]*$/ { next }
            column && NF {
                samples++
                for (i=column; i<column+3; i++) {
                    if ($i !~ /^[0-9]+([.][0-9]+)?$/ || $i < 0 || $i > 100) bad=1
                }
                if ($(column)+$(column+1)+$(column+2) < 98 ||
                    $(column)+$(column+1)+$(column+2) > 102) bad=1
                idle=$(column+2)
            }
            END {
                if (samples != 2 || bad) print "?"
                else printf "%.0f", 100-idle
            }
        '\'')
    fi
    printf "CPU %s%% · RAM %s\n" "${cpu:-?}" "${ram:-?G/?G}"
' 2>/dev/null) || result=$fallback
printf '%s\n' "$result"
