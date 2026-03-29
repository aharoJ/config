# path: ~/.config/fish/internal/net/net.fish
# description: Network diagnostics and macOS network location switching.
#              Home = DHCP DNS (router handles NextDNS upstream).
#              Work = DHCP DNS (WesternU EDU captive portal).
# usage:
#   net home              → DHCP DNS (router upstream = NextDNS)
#   net work              → DHCP DNS (WesternU EDU)
#   net status            → show current location + DNS servers
#   net bench             → benchmark DNS resolvers (current, cloudflare-mw, google, nextdns, router)
#   net quality           → run Apple networkQuality (throughput + RPM)
# removed: net compare    — obsolete after Option C (both profiles use DHCP DNS)
#   net curltime [url]    → curl timing breakdown (dns/connect/tls/ttfb/total)
#   net flush             → flush macOS DNS caches (mDNSResponder + DS)
#   net wifi              → show current WiFi connection details
#   net devices           → list DHCP clients from router
#   net monitor           → router health (load, RAM, temp, SQM, devices, uptime)
#   net scan              → detect unknown/misplaced devices vs known-devices.conf
#   net traffic           → per-device bandwidth via nlbwmon
#   net dns               → show .lan hostname mappings from router dnsmasq
#   net wake [device]     → wake device via WoL magic packet (default: ubuntu)
# patched: 2026-03-24 — R1 cross-review (6 LLMs): median bug, new subcommands,
#          Option C DNS (router upstream = Cloudflare), benchmark caveats
# patched: 2026-03-24 — R2 cross-review (6 LLMs): median scoping bug, remove
#          dead compare subcommand, wifi parsing fallbacks
# patched: 2026-03-24 — R3 cross-review (6 LLMs): signal/noise awk field fix,
#          remove dead bssid, defensive math -s0 on median
# patched: 2026-03-24 — R4 cross-review (5 LLMs): mktemp guard, networkQuality
#          check, flush error handling, curl -- separator, signal/noise label
# patched: 2026-03-25 — R5 cross-review (5 LLMs): flush tracks both command
#          statuses, home/work guards DNS+DHCP commands
# patched: 2026-03-25 — Phase 2 ad-blocking deploy: comments Cloudflare → NextDNS,
#          bench server 1.1.1.1 → 1.1.1.2 (cloudflare-mw), %-14s column fix
# patched: 2026-03-26 — Flint 2 verification: no code changes needed, router-agnostic
# patched: 2026-03-26 — Phase 4 monitoring: net devices, monitor, scan, traffic
#          (2-round cross-review, 5 LLMs each, 10 total, 0 open disagreements)
# patched: 2026-03-26 — Phase 5 isolation: VLAN column in devices/scan/monitor
#          (2-round research cross-review, 5 LLMs each, 10 total, converged)
# patched: 2026-03-27 — Phase 6 local DNS: net dns subcommand
#          (4-round research cross-review, 5 LLMs each, 19 total, converged)
# patched: 2026-03-28 — Phase 7 WoL: net wake subcommand
#          (2-round research cross-review, 5 LLMs each, 10 total, converged)
# date: 2026-03-28

function net --description "Network diagnostics and location switching"
    set -l subcmd $argv[1]

    if test -z "$subcmd"
        echo "usage: net [home|work|status|bench|quality|curltime|flush|wifi|devices|monitor|scan|traffic|dns|wake]"
        return 1
    end

    switch $subcmd
        case status
            set -l loc (networksetup -getcurrentlocation)
            set -l dns (networksetup -getdnsservers Wi-Fi)
            set_color yellow
            echo "location: $loc"
            set_color normal
            if string match -q "There aren't any DNS Servers*" -- "$dns"
                echo "dns: automatic (DHCP)"
            else
                echo "dns: $dns"
            end

        case bench
            set -l iface (networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2; exit}')
            set -l router (ipconfig getoption $iface router 2>/dev/null)
            set -l names current cloudflare-mw google nextdns
            set -l servers "" 1.1.1.2 8.8.8.8 45.90.28.98
            if test -n "$router"
                set -a names router
                set -a servers $router
            end

            set -l loc (networksetup -getcurrentlocation)
            set -l dns (networksetup -getdnsservers Wi-Fi)
            if string match -q "There aren't any DNS Servers*" -- "$dns"
                set dns "automatic (DHCP)"
            end
            echo "net: dns benchmark (3 queries each) — location: $loc, dns: $dns"
            set_color brblack
            echo "      (dig bypasses mDNSResponder — real app DNS may differ)"
            set_color normal
            set -l best_name ""; set -l best_ms 99999

            for i in (seq (count $names))
                set -l name $names[$i]
                set -l server $servers[$i]
                set -l times

                for _q in 1 2 3
                    set -l cmd dig +noall +stats google.com
                    test -n "$server"; and set -a cmd @$server
                    set -l ms ($cmd 2>/dev/null | awk '/Query time:/{print $4}')
                    test -n "$ms"; and set -a times $ms
                end

                if test (count $times) -eq 0
                    printf "  %-14s %s\n" $name "timeout"
                    continue
                end

                # Median: handle 1, 2, or 3 results
                set -l sorted (printf '%s\n' $times | sort -n)
                set -l cnt (count $sorted)
                set -l median
                if test $cnt -eq 1
                    set median $sorted[1]
                else if test $cnt -eq 2
                    set median (math -s0 "($sorted[1] + $sorted[2]) / 2")
                else
                    set median $sorted[2]
                end

                if test $median -lt $best_ms
                    set best_ms $median
                    set best_name $name
                end

                printf "  %-14s %sms\n" $name $median
            end

            if test -n "$best_name"
                set_color green
                printf "  fastest: %s (%sms)\n" $best_name $best_ms
                set_color normal
            end

        case quality
            if not command -q networkQuality
                echo "net: networkQuality not found (requires macOS 12+)"
                return 1
            end
            echo "net: running networkQuality (throughput + responsiveness)"
            echo "      RPM > 2000 = High | 600-2000 = Medium | < 600 = Low"
            echo ""
            networkQuality -v

        case curltime
            set -l url $argv[2]
            if test -z "$url"
                set url "https://www.google.com"
            end
            echo "net: curl timing breakdown → $url"
            echo ""
            for _q in 1 2 3
                curl -o /dev/null -s -w "  dns:%{time_namelookup}s  connect:%{time_connect}s  tls:%{time_appconnect}s  ttfb:%{time_starttransfer}s  total:%{time_total}s\n" -- "$url"
            end

        case flush
            echo "net: flushing DNS caches"
            set -l ds_ok 0; set -l mdns_ok 0
            sudo dscacheutil -flushcache; and set ds_ok 1
            sudo killall -HUP mDNSResponder 2>/dev/null; and set mdns_ok 1
            if test $ds_ok -eq 1 -a $mdns_ok -eq 1
                set_color green
                echo "net: flushed mDNSResponder + Directory Services cache"
                set_color normal
            else if test $ds_ok -eq 1
                echo "net: flushed Directory Services cache (mDNSResponder not running)"
            else if test $mdns_ok -eq 1
                echo "net: flushed mDNSResponder cache (Directory Services flush failed)"
            else
                echo "net: failed to flush DNS caches"
                return 1
            end

        case wifi
            echo "net: wifi connection details"
            echo ""
            # Pipe system_profiler directly — command substitution collapses newlines
            set -l tmpfile (mktemp); or begin; echo "net: failed to create temp file"; return 1; end
            system_profiler SPAirPortDataType 2>/dev/null > $tmpfile

            set -l ssid (awk '/Current Network Information:/{getline; gsub(/^ +| *:$/, ""); print; exit}' $tmpfile)
            set -l channel (awk '/Current Network Information:/,/Other Local Wi-Fi/{if(/Channel:/){print $2; exit}}' $tmpfile)
            set -l phymode (awk '/Current Network Information:/,/Other Local Wi-Fi/{if(/PHY Mode:/){print $NF; exit}}' $tmpfile)
            set -l rssi (awk '/Current Network Information:/,/Other Local Wi-Fi/{if(/Signal \/ Noise:/){print $4 " / " $7; exit}}' $tmpfile)
            set -l txrate (awk '/Current Network Information:/,/Other Local Wi-Fi/{if(/Transmit Rate:/){print $3; exit}}' $tmpfile)
            rm -f $tmpfile

            test -z "$ssid"; and set ssid "unknown"
            test -z "$channel"; and set channel "unknown"
            test -z "$phymode"; and set phymode "unknown"
            test -z "$txrate"; and set txrate "unknown"
            test -z "$rssi"; and set rssi "unknown"

            printf "  ssid:     %s\n" "$ssid"
            printf "  channel:  %s\n" "$channel"
            printf "  phy mode: %s\n" "$phymode"
            printf "  tx rate:  %s Mbps\n" "$txrate"
            printf "  sig/noise: %s dBm\n" "$rssi"
            echo ""
            set_color brblack
            echo "  tip: Option+Click WiFi icon for live details"
            set_color normal

        case devices
            echo "net: devices on network (via router)"
            echo ""
            if not ssh -o ConnectTimeout=3 flint true 2>/dev/null
                set_color red; echo "  router unreachable (ssh flint failed)"; set_color normal
                return 1
            end
            # Parse leases on router with awk → tab-delimited (handles hostnames with spaces)
            set -l lines (ssh flint "awk '{name=\$4; if(name==\"*\") name=\"(unknown)\"; printf \"%s\\t%s\\t%s\\n\", name, \$3, \$2}' /tmp/dhcp.leases 2>/dev/null" 2>/dev/null)
            if test $status -ne 0
                set_color red; echo "  failed to fetch data from router"; set_color normal
                return 1
            end
            printf "  %-20s %-15s %-17s %-6s\n" "HOSTNAME" "IP" "MAC" "VLAN"
            set_color brblack
            printf "  %-20s %-15s %-17s %-6s\n" "--------" "--" "---" "----"
            set_color normal
            for line in $lines
                set -l parts (string split \t -- $line)
                if test (count $parts) -ge 3
                    set -l vlan "main"
                    if string match -q "192.168.10.*" $parts[2]
                        set vlan "iot"
                    end
                    if test "$vlan" = "iot"
                        set_color yellow
                    end
                    printf "  %-20s %-15s %-17s %-6s\n" $parts[1] $parts[2] $parts[3] $vlan
                    if test "$vlan" = "iot"
                        set_color normal
                    end
                end
            end

        case monitor
            echo "net: router health (via ssh flint)"
            echo ""
            if not ssh -o ConnectTimeout=3 flint true 2>/dev/null
                set_color red; echo "  router unreachable (ssh flint failed)"; set_color normal
                return 1
            end
            # Stable awk-based parsing on router side to avoid field-index brittleness
            set -l data (ssh flint "
                echo '::LOAD::'; cat /proc/loadavg
                echo '::MEM::'; awk '/MemTotal/{t=\$2} /MemAvailable/{a=\$2} END{printf \"%d %d\n\", t/1024, a/1024}' /proc/meminfo
                echo '::TEMP::'; cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null
                echo '::DEVICES::'; awk 'END{printf \"%d %d\n\", NR, iot} /192\\.168\\.10\\./{iot++}' /tmp/dhcp.leases 2>/dev/null
                echo '::CAKE_UP::'; tc -s qdisc show dev eth1 2>/dev/null | head -3
                echo '::CAKE_DN::'; tc -s qdisc show dev ifb4eth1 2>/dev/null | head -3
                echo '::UPTIME::'; uptime
            " 2>/dev/null)
            if test $status -ne 0
                set_color red; echo "  failed to fetch data from router"; set_color normal
                return 1
            end

            set -l section ""
            for line in $data
                switch $line
                    case "::LOAD::"; set section load; continue
                    case "::MEM::"; set section mem; continue
                    case "::TEMP::"; set section temp; continue
                    case "::DEVICES::"; set section devices; continue
                    case "::CAKE_UP::"; set section cake_up; continue
                    case "::CAKE_DN::"; set section cake_dn; continue
                    case "::UPTIME::"; set section uptime; continue
                end
                switch $section
                    case load
                        set -l parts (string split -n " " -- $line)
                        if test (count $parts) -ge 3
                            printf "  cpu load:    %s %s %s\n" $parts[1] $parts[2] $parts[3]
                        end
                    case mem
                        set -l parts (string split -n " " -- $line)
                        if test (count $parts) -ge 2
                            set -l total_mb $parts[1]
                            set -l avail_mb $parts[2]
                            set -l used_mb (math -s0 "$total_mb - $avail_mb")
                            printf "  memory:      %sMB used / %sMB total (%sMB available)\n" $used_mb $total_mb $avail_mb
                        end
                    case temp
                        if test -n "$line"
                            set -l temp_c (math -s1 "$line / 1000")
                            printf "  temperature: %s°C\n" $temp_c
                        end
                    case devices
                        # Atomic: single awk outputs "total iot" on one line
                        set -l parts (string split -n " " -- $line)
                        if test (count $parts) -ge 2
                            set -l total $parts[1]
                            set -l iot $parts[2]
                            set -l main_count (math "$total - $iot")
                            printf "  devices:     %s connected (%s main, %s iot)\n" $total $main_count $iot
                        else if test (count $parts) -ge 1
                            printf "  devices:     %s connected\n" $parts[1]
                        end
                    case cake_up
                        if string match -q "*cake*" -- $line
                            printf "  sqm upload:  "
                            set_color green; echo "active"; set_color normal
                        end
                    case cake_dn
                        if string match -q "*cake*" -- $line
                            printf "  sqm download: "
                            set_color green; echo "active"; set_color normal
                        end
                    case uptime
                        printf "  uptime:      %s\n" (string trim -- $line)
                end
            end

        case scan
            set -l known_file ~/.config/net/known-devices.conf
            if not test -f $known_file
                echo "net: known devices file not found at $known_file"
                echo "  create it with: MAC  Name  Type  VLAN  Hostname (one per line, # for comments)"
                return 1
            end

            echo "net: scanning for unknown devices"
            echo ""
            if not ssh -o ConnectTimeout=3 flint true 2>/dev/null
                set_color red; echo "  router unreachable (ssh flint failed)"; set_color normal
                return 1
            end
            # Single SSH call — fetch all lease data, parse locally (no N+1)
            set -l leases (ssh flint "awk '{printf \"%s\\t%s\\t%s\\n\", tolower(\$2), \$3, \$4}' /tmp/dhcp.leases 2>/dev/null" 2>/dev/null)
            if test $status -ne 0
                set_color red; echo "  failed to fetch data from router"; set_color normal
                return 1
            end
            if test -z "$leases"
                set_color yellow; echo "  no DHCP leases found"; set_color normal
                return 0
            end
            set -l unknown_count 0
            set -l misplaced_count 0

            for line in $leases
                set -l parts (string split \t -- $line)
                if test (count $parts) -ge 3
                    set -l mac $parts[1]
                    set -l ip $parts[2]
                    set -l name $parts[3]
                    test "$name" = "*"; and set name "(unnamed)"

                    # Detect current VLAN from IP prefix
                    set -l current_vlan "main"
                    if string match -q "192.168.10.*" $ip
                        set current_vlan "iot"
                    end

                    # Anchored awk: match first field only, skip comments, first match wins
                    set -l expected_vlan (awk -v mac="$mac" 'tolower($1)==mac {print $4; exit}' $known_file 2>/dev/null | string trim)

                    if test -z "$expected_vlan"
                        set unknown_count (math $unknown_count + 1)
                        set_color red
                        printf "  UNKNOWN: %s  %s  %s  [%s]\n" $mac $ip $name $current_vlan
                        set_color normal
                    else if test "$expected_vlan" != "$current_vlan"
                        set misplaced_count (math $misplaced_count + 1)
                        set_color yellow
                        printf "  MISPLACED: %s  %s  %s  [on %s, expected %s]\n" $mac $ip $name $current_vlan $expected_vlan
                        set_color normal
                    end
                end
            end

            if test $unknown_count -eq 0 -a $misplaced_count -eq 0
                set_color green
                echo "  all devices known and on correct VLANs"
                set_color normal
            else
                echo ""
                if test $unknown_count -gt 0
                    set_color yellow
                    printf "  %d unknown device(s) found\n" $unknown_count
                    set_color normal
                end
                if test $misplaced_count -gt 0
                    set_color yellow
                    printf "  %d device(s) on wrong VLAN\n" $misplaced_count
                    set_color normal
                end
            end

        case traffic
            if not ssh -o ConnectTimeout=3 flint true 2>/dev/null
                set_color red; echo "net: router unreachable (ssh flint failed)"; set_color normal
                return 1
            end
            # Single SSH call: check nlbw exists and fetch data in one shot
            set -l lines (ssh flint "command -v nlbw >/dev/null 2>&1 || { echo '::MISSING::'; exit 0; }; nlbw -c csv -g mac 2>/dev/null" 2>/dev/null)
            if test $status -ne 0
                set_color red; echo "net: failed to fetch data from router"; set_color normal
                return 1
            end
            if test (count $lines) -ge 1 -a "$lines[1]" = "::MISSING::"
                echo "net: nlbwmon not installed on router"
                echo "  install: ssh flint 'apk add nlbwmon'"
                return 1
            end

            echo "net: per-device bandwidth (via nlbwmon)"
            echo ""
            printf "  %-17s %12s %12s\n" "MAC" "DOWNLOAD" "UPLOAD"
            set_color brblack
            printf "  %-17s %12s %12s\n" "---" "--------" "------"
            set_color normal

            # nlbw outputs tab-separated quoted fields: "mac" "conns" "rx_bytes" "rx_pkts" "tx_bytes" "tx_pkts"
            for line in $lines
                set -l clean (string replace -a '"' '' -- $line)
                set -l parts (string split \t -- $clean)
                if test (count $parts) -ge 5
                    set -l mac $parts[1]
                    test "$mac" = "mac"; and continue
                    test -z "$parts[3]" -o "$parts[3]" = "0"; and test -z "$parts[5]" -o "$parts[5]" = "0"; and continue
                    set -l rx_mb (math -s1 "$parts[3] / 1048576")
                    set -l tx_mb (math -s1 "$parts[5] / 1048576")
                    printf "  %-17s %10s MB %10s MB\n" $mac $rx_mb $tx_mb
                end
            end

        case dns
            echo "net: .lan hostname mappings (via router dnsmasq)"
            echo ""
            if not ssh -o ConnectTimeout=3 flint true 2>/dev/null
                set_color red; echo "  router unreachable (ssh flint failed)"; set_color normal
                return 1
            end
            # Extract host entries (dns='1') and domain entries from UCI
            # UCI format: dhcp.@host[N].key='val' or dhcp.named.key='val'
            # Pipeline split: ssh+awk first (check $pipestatus), sort after
            set -l raw (ssh flint "
                uci show dhcp 2>&1 || { echo '::UCI_FAIL::'; exit 1; }
            " 2>/dev/null | awk -F= '
                /::UCI_FAIL::/ { fail=1; exit 1 }
                {
                    key=$1; val=$2
                    gsub(/^dhcp\./, "", key)
                    n=split(key, kp, ".")
                    sec=""
                    for(i=1;i<n;i++) sec = (sec=="" ? kp[i] : sec"."kp[i])
                    field=kp[n]
                    gsub(/^'"'"'/, "", val); gsub(/'"'"'$/, "", val)
                }
                field=="dns" && val=="1" { hosts[sec]=1 }
                field=="name" { names[sec]=val }
                field=="ip" { ips[sec]=val }
                END {
                    if (fail) exit 1
                    for (s in names) {
                        if (s in ips) {
                            type = (s in hosts) ? "host" : "domain"
                            printf "%s\t%s\t%s\n", names[s], ips[s], type
                        }
                    }
                }
            ')
            set -l ssh_rc $pipestatus[1]; set -l awk_rc $pipestatus[2]
            if test $ssh_rc -ne 0
                set_color red; echo "  router connection failed"; set_color normal
                return 1
            else if test $awk_rc -ne 0
                set_color red; echo "  failed to parse data from router (UCI error)"; set_color normal
                return 1
            end
            if test (count $raw) -eq 0
                echo "  no hostname mappings found"
                return 0
            end
            set -l entries (printf '%s\n' $raw | sort -t\t -k2)

            printf "  %-20s %-16s %-8s %-6s\n" "HOSTNAME" "IP" "TYPE" "VLAN"
            set_color brblack
            printf "  %-20s %-16s %-8s %-6s\n" "--------" "--" "----" "----"
            set_color normal
            for line in $entries
                set -l parts (string split \t -- $line)
                if test (count $parts) -ge 3
                    set -l hname $parts[1]
                    set -l ip $parts[2]
                    set -l type $parts[3]
                    set -l vlan "main"
                    if string match -q "192.168.10.*" $ip
                        set vlan "iot"
                    end
                    if test "$vlan" = "iot"
                        set_color yellow
                    end
                    printf "  %-20s %-16s %-8s %-6s\n" "$hname.lan" $ip $type $vlan
                    if test "$vlan" = "iot"
                        set_color normal
                    end
                end
            end

        case wake
            set -l target "ubuntu"
            if test (count $argv) -ge 2
                set target $argv[2]
            end

            # Reject placeholder hostname (known-devices.conf uses '-' for no DNS)
            if test "$target" = "-"
                set_color red; echo "net: '-' is not a valid wake target"; set_color normal
                return 1
            end

            set -l conf ~/.config/net/known-devices.conf
            if not test -f $conf
                set_color red; echo "net: known-devices.conf not found"; set_color normal
                return 1
            end

            # Lookup MAC and device type in single awk pass (skip comments)
            set -l info (awk -v h="$target" '!/^[[:space:]]*#/ && $5 == h {print $1 "\t" $3; exit}' $conf)
            if test -z "$info"
                set_color red; echo "net: device '$target' not found in known-devices.conf"; set_color normal
                return 1
            end
            set -l mac (string split \t -- $info)[1]
            set -l dtype (string split \t -- $info)[2]

            # Validate MAC format before passing to remote shell
            if not string match -qr '^[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}$' -- $mac
                set_color red; echo "net: invalid MAC '$mac' in known-devices.conf"; set_color normal
                return 1
            end

            # Block device types that don't support WoL
            if contains -- $dtype phone tablet laptop
                set_color red; echo "net: '$target' is $dtype (WiFi-only, WoL not supported)"; set_color normal
                return 1
            end

            # Check if already awake (-W 1000 = 1s timeout on macOS, which uses ms)
            if ping -c 1 -W 1000 "$target.lan" >/dev/null 2>&1
                set_color green; echo "net: $target.lan is already awake"; set_color normal
                return 0
            end

            # Pre-check router SSH (consistent with devices/monitor/scan/traffic/dns)
            if not ssh -o ConnectTimeout=3 flint true 2>/dev/null
                set_color red; echo "net: router unreachable (ssh flint failed)"; set_color normal
                return 1
            end

            # Send magic packet via router
            set -l wake_err (ssh flint "etherwake -i br-lan $mac" 2>&1)
            if test $status -ne 0
                set_color red
                if string match -q "*not found*" -- $wake_err
                    echo "net: etherwake not installed on router (apk add etherwake)"
                else
                    echo "net: failed to send magic packet: $wake_err"
                end
                set_color normal
                return 1
            end

            set_color yellow; echo "net: magic packet sent to $target ($mac)"; set_color normal

            # Poll for wake — ping every 2s, wall-clock timeout 30s
            set -l start (date +%s)
            while true
                sleep 2
                if ping -c 1 -W 1000 "$target.lan" >/dev/null 2>&1
                    set -l elapsed (math (date +%s) - $start)
                    set_color green; echo "net: $target.lan woke in "$elapsed"s"; set_color normal
                    return 0
                end
                set -l elapsed (math (date +%s) - $start)
                if test $elapsed -ge 30
                    break
                end
            end

            set_color red; echo "net: $target.lan failed to wake after 30s"; set_color normal
            return 1

        case home work
            set -l iface (networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2; exit}')
            if test -z "$iface"
                echo "net: could not find Wi-Fi interface"
                return 1
            end

            sudo -v; or begin; echo "net: sudo auth failed"; return 1; end

            # Both home and work use DHCP DNS (automatic)
            # Home: router upstream = NextDNS (set in router admin UI)
            # Work: WesternU EDU network provides its own DNS via DHCP
            set -l loc Home; set -l msg "home — DHCP DNS (router → NextDNS upstream)"
            if test "$subcmd" = work
                set loc WesternU; set msg "work — DHCP DNS (WesternU EDU)"
            end

            sudo networksetup -switchtolocation $loc 2>/dev/null
            or begin
                sudo networksetup -createlocation $loc populate >/dev/null
                and sudo networksetup -switchtolocation $loc 2>/dev/null
                or begin; echo "net: failed to switch to '$loc'"; return 1; end
            end

            # Both use automatic DNS — no hardcoded DNS on Mac side
            sudo networksetup -setdnsservers Wi-Fi empty
            and sudo ipconfig set $iface DHCP
            or begin; echo "net: failed to configure network"; return 1; end
            set_color green
            echo "net: $msg"
            set_color normal

        case '*'
            echo "unknown: '$subcmd'"
            echo "usage: net [home|work|status|bench|quality|curltime|flush|wifi|devices|monitor|scan|traffic|dns|wake]"
            return 1
    end
end
