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
# date: 2026-03-26

function net --description "Network diagnostics and location switching"
    set -l subcmd $argv[1]

    if test -z "$subcmd"
        echo "usage: net [home|work|status|bench|quality|curltime|flush|wifi]"
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
            echo "usage: net [home|work|status|bench|quality|curltime|flush|wifi]"
            return 1
    end
end
