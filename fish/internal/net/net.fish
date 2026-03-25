# path: ~/.config/fish/internal/net/net.fish
# description: Switch macOS network location between home (Cloudflare DNS)
#              and work/WesternU (automatic DNS). Creates locations on first run.
# usage:
#   net home              → Cloudflare DNS (1.1.1.1, 1.0.0.1)
#   net work              → automatic DNS (DHCP-assigned)
#   net status            → show current location + DNS servers
#   net bench             → benchmark DNS resolvers (current, cloudflare, google, router)
#   net compare           → bench home vs work side-by-side, restore original config
# date: 2026-03-24

function net --description "Switch network location (home/work)"
    set -l subcmd $argv[1]

    if test -z "$subcmd"
        echo "usage: net [home|work|status|bench|compare]"
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

                # Median: sort and take middle value
                set -l sorted (printf '%s\n' $times | sort -n)
                set -l median $sorted[2]

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

            # Bench both profiles
            set -l home_results
            set -l work_results

            for profile in home work
                # Switch profile silently
                if test "$profile" = home
                    sudo networksetup -switchtolocation Home 2>/dev/null
                    or begin
                        sudo networksetup -createlocation Home populate >/dev/null
                        and sudo networksetup -switchtolocation Home 2>/dev/null
                    end
                    sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1
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
                        set -a results $sorted[2]
                    end
                end

                if test "$profile" = home
                    set home_results $results
                else
                    set work_results $results
                end
            end

            # Print side-by-side
            printf "  %-12s %10s %10s %8s\n" "" "home" "work" "diff"
            set_color brblack
            printf "  %-12s %10s %10s %8s\n" "" "(cloudflare)" "(dhcp)" ""
            set_color normal
            echo "  ────────────────────────────────────────"

            for i in (seq (count $names))
                set -l h $home_results[$i]
                set -l w $work_results[$i]
                set -l h_str (test $h -eq -1; and echo "timeout"; or echo "$h"ms)
                set -l w_str (test $w -eq -1; and echo "timeout"; or echo "$w"ms)
                set -l diff_str ""
                if test $h -ne -1 -a $w -ne -1
                    set -l d (math "$h - $w")
                    if test $d -gt 0
                        set diff_str "work +$d"
                    else if test $d -lt 0
                        set d (math "0 - $d")
                        set diff_str "home +$d"
                    else
                        set diff_str "tie"
                    end
                end
                printf "  %-12s %10s %10s %8s\n" $names[$i] $h_str $w_str $diff_str
            end

            # Restore original
            echo ""
            if test "$original" = Home
                sudo networksetup -switchtolocation Home 2>/dev/null
                sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1
            else
                sudo networksetup -switchtolocation "$original" 2>/dev/null
                sudo networksetup -setdnsservers Wi-Fi empty
            end
            sudo ipconfig set $iface DHCP
            set_color yellow
            echo "  restored: $original"
            set_color normal

        case home work
            # Resolve Wi-Fi interface dynamically (not always en0)
            set -l iface (networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2; exit}')
            if test -z "$iface"
                echo "net: could not find Wi-Fi interface"
                return 1
            end

            sudo -v; or begin; echo "net: sudo auth failed"; return 1; end

            set -l loc Home; set -l dns 1.1.1.1 1.0.0.1; set -l msg "home — Cloudflare DNS (1.1.1.1, 1.0.0.1)"
            if test "$subcmd" = work
                set loc WesternU; set dns empty; set msg "work — automatic DNS (WesternU)"
            end

            sudo networksetup -switchtolocation $loc 2>/dev/null
            or begin
                sudo networksetup -createlocation $loc populate >/dev/null
                and sudo networksetup -switchtolocation $loc 2>/dev/null
                or begin; echo "net: failed to switch to '$loc'"; return 1; end
            end

            sudo networksetup -setdnsservers Wi-Fi $dns
            sudo ipconfig set $iface DHCP
            set_color green
            echo "net: $msg"
            set_color normal

        case '*'
            echo "unknown: '$subcmd'"
            echo "usage: net [home|work|status|bench|compare]"
            return 1
    end
end
