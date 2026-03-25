# path: ~/.config/fish/internal/net/net.fish
# description: Network diagnostics and macOS network location switching.
#              Home = DHCP DNS (router handles Cloudflare upstream).
#              Work = DHCP DNS (WesternU EDU captive portal).
# usage:
#   net home              → DHCP DNS (router upstream = Cloudflare)
#   net work              → DHCP DNS (WesternU EDU)
#   net status            → show current location + DNS servers
#   net bench             → benchmark DNS resolvers (current, cloudflare, google, router)
#   net compare           → bench home vs work side-by-side, restore original config
#   net quality           → run Apple networkQuality (throughput + RPM)
#   net curltime [url]    → curl timing breakdown (dns/connect/tls/ttfb/total)
#   net flush             → flush macOS DNS caches (mDNSResponder + DS)
#   net wifi              → show current WiFi connection details
# patched: 2026-03-24 — R1 cross-review (6 LLMs): median bug, new subcommands,
#          Option C DNS (router upstream = Cloudflare), benchmark caveats
# date: 2026-03-24

function net --description "Network diagnostics and location switching"
    set -l subcmd $argv[1]

    if test -z "$subcmd"
        echo "usage: net [home|work|status|bench|compare|quality|curltime|flush|wifi]"
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
            set -l names current cloudflare google
            set -l servers "" 1.1.1.1 8.8.8.8
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
                    printf "  %-12s %s\n" $name "timeout"
                    continue
                end

                # Median: handle 1, 2, or 3 results
                set -l sorted (printf '%s\n' $times | sort -n)
                set -l cnt (count $sorted)
                if test $cnt -eq 1
                    set -l median $sorted[1]
                else if test $cnt -eq 2
                    # Average of two (integer division)
                    set -l median (math "($sorted[1] + $sorted[2]) / 2")
                else
                    set -l median $sorted[2]
                end

                if test $median -lt $best_ms
                    set best_ms $median
                    set best_name $name
                end

                printf "  %-12s %sms\n" $name $median
            end

            if test -n "$best_name"
                set_color green
                printf "  fastest: %s (%sms)\n" $best_name $best_ms
                set_color normal
            end

        case compare
            set -l iface (networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2; exit}')
            if test -z "$iface"
                echo "net: could not find Wi-Fi interface"
                return 1
            end

            set -l original (networksetup -getcurrentlocation)
            sudo -v; or begin; echo "net: sudo auth failed"; return 1; end

            set -l names cloudflare google
            set -l servers 1.1.1.1 8.8.8.8
            set -l router (ipconfig getoption $iface router 2>/dev/null)
            if test -n "$router"
                set -a names router
                set -a servers $router
            end

            echo "net: compare home vs work (3 queries each)"
            echo ""

            set -l home_results
            set -l work_results

            for profile in home work
                if test "$profile" = home
                    sudo networksetup -switchtolocation Home 2>/dev/null
                    or begin
                        sudo networksetup -createlocation Home populate >/dev/null
                        and sudo networksetup -switchtolocation Home 2>/dev/null
                    end
                    sudo networksetup -setdnsservers Wi-Fi empty
                else
                    sudo networksetup -switchtolocation WesternU 2>/dev/null
                    or begin
                        sudo networksetup -createlocation WesternU populate >/dev/null
                        and sudo networksetup -switchtolocation WesternU 2>/dev/null
                    end
                    sudo networksetup -setdnsservers Wi-Fi empty
                end
                sudo ipconfig set $iface DHCP
                sleep 1

                set -l results
                for i in (seq (count $names))
                    set -l server $servers[$i]
                    set -l times
                    for _q in 1 2 3
                        set -l ms (dig +noall +stats google.com @$server 2>/dev/null | awk '/Query time:/{print $4}')
                        test -n "$ms"; and set -a times $ms
                    end
                    if test (count $times) -eq 0
                        set -a results -1
                    else
                        set -l sorted (printf '%s\n' $times | sort -n)
                        set -l cnt (count $sorted)
                        if test $cnt -eq 1
                            set -a results $sorted[1]
                        else if test $cnt -eq 2
                            set -a results (math "($sorted[1] + $sorted[2]) / 2")
                        else
                            set -a results $sorted[2]
                        end
                    end
                end

                if test "$profile" = home
                    set home_results $results
                else
                    set work_results $results
                end
            end

            # Print side-by-side
            printf "  %-12s %10s %10s %10s\n" "" "home" "work" "winner"
            echo "  ──────────────────────────────────────────"

            for i in (seq (count $names))
                set -l h $home_results[$i]
                set -l w $work_results[$i]
                set -l h_str (test $h -eq -1; and echo "timeout"; or echo "$h"ms)
                set -l w_str (test $w -eq -1; and echo "timeout"; or echo "$w"ms)
                set -l winner ""
                if test $h -ne -1 -a $w -ne -1
                    set -l d (math "$h - $w")
                    if test $d -gt 0
                        set winner "work ↓$d"ms
                    else if test $d -lt 0
                        set d (math "0 - $d")
                        set winner "home ↓$d"ms
                    else
                        set winner "tie"
                    end
                end
                printf "  %-12s %10s %10s %10s\n" $names[$i] $h_str $w_str $winner
            end

            # Restore original
            echo ""
            sudo networksetup -switchtolocation "$original" 2>/dev/null
            sudo networksetup -setdnsservers Wi-Fi empty
            sudo ipconfig set $iface DHCP
            set_color yellow
            echo "  restored: $original"
            set_color normal

        case quality
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
                curl -o /dev/null -s -w "  dns:%{time_namelookup}s  connect:%{time_connect}s  tls:%{time_appconnect}s  ttfb:%{time_starttransfer}s  total:%{time_total}s\n" "$url"
            end

        case flush
            echo "net: flushing DNS caches"
            sudo dscacheutil -flushcache
            sudo killall -HUP mDNSResponder
            set_color green
            echo "net: flushed mDNSResponder + Directory Services cache"
            set_color normal

        case wifi
            echo "net: wifi connection details"
            echo ""
            # Current connection info via system_profiler
            set -l info (system_profiler SPAirPortDataType 2>/dev/null)
            set -l channel (echo "$info" | awk '/Channel:/{print $2; exit}')
            set -l phymode (echo "$info" | awk '/PHY Mode:/{print $NF; exit}')
            set -l rssi (echo "$info" | awk '/Signal \/ Noise:/{print $4 " / " $6; exit}')
            set -l txrate (echo "$info" | awk '/Transmit Rate:/{print $3; exit}')
            set -l ssid (echo "$info" | awk '/Current Network Information:/{getline; gsub(/^ +| *:$/, ""); print; exit}')
            set -l bssid (echo "$info" | awk '/BSSID:/{print $2; exit}')

            printf "  ssid:     %s\n" "$ssid"
            printf "  channel:  %s\n" "$channel"
            printf "  phy mode: %s\n" "$phymode"
            printf "  tx rate:  %s Mbps\n" "$txrate"
            printf "  signal:   %s dBm\n" "$rssi"
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
            # Home: router upstream = Cloudflare (set in router admin UI)
            # Work: WesternU EDU network provides its own DNS via DHCP
            set -l loc Home; set -l msg "home — DHCP DNS (router → Cloudflare upstream)"
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
            sudo ipconfig set $iface DHCP
            set_color green
            echo "net: $msg"
            set_color normal

        case '*'
            echo "unknown: '$subcmd'"
            echo "usage: net [home|work|status|bench|compare|quality|curltime|flush|wifi]"
            return 1
    end
end
