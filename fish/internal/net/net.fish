# path: ~/.config/fish/internal/net/net.fish
# description: Switch macOS network location between home (Cloudflare DNS)
#              and work/WesternU (automatic DNS). Creates locations on first run.
# usage:
#   net home              → Cloudflare DNS (1.1.1.1, 1.0.0.1)
#   net work              → automatic DNS (DHCP-assigned)
#   net status            → show current location + DNS servers
# date: 2026-03-23

function net --description "Switch network location (home/work)"
    set -l subcmd $argv[1]

    if test -z "$subcmd"
        echo "usage: net [home|work|status]"
        return 1
    end

    switch $subcmd
        case status
            set -l loc (networksetup -getcurrentlocation)
            set -l dns (networksetup -getdnsservers Wi-Fi)
            set_color yellow
            echo "location: $loc"
            set_color normal
            echo "dns: $dns"

        case home
            # Cloudflare DNS for home R6700v3
            sudo networksetup -switchtolocation Home 2>/dev/null
            or begin
                sudo networksetup -createlocation Home populate >/dev/null
                sudo networksetup -switchtolocation Home
            end
            sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1
            sudo ipconfig set en0 DHCP
            set_color green
            echo "net: home — Cloudflare DNS (1.1.1.1, 1.0.0.1)"
            set_color normal

        case work
            # Automatic DNS for WesternU EDU
            sudo networksetup -switchtolocation WesternU 2>/dev/null
            or begin
                sudo networksetup -createlocation WesternU populate >/dev/null
                sudo networksetup -switchtolocation WesternU
            end
            sudo networksetup -setdnsservers Wi-Fi empty
            sudo ipconfig set en0 DHCP
            set_color green
            echo "net: work — automatic DNS (WesternU)"
            set_color normal

        case '*'
            echo "unknown: '$subcmd'"
            echo "usage: net [home|work|status]"
            return 1
    end
end
