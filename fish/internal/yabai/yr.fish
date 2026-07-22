# path: ~/.config/fish/internal/yabai/yr.fish
# description: Restart yabai + skhd and apply a layout profile.
#              Also swaps the skhd modules/active symlink to match the profile.
# usage:
#   yr                  → restart with current profile (detected from symlink)
#   yr -P bsp           → restart with BSP profile (explicit override)
#   yr -P float         → restart with float profile (explicit override)
#   yr --status         → show current yabai + skhd state (no restart)
# date: 2026-02-08
# changelog: 2026-04-07 | D-01: Extract symlink swap to _swap_skhd_profile helper
#            2026-04-07 | D-03: Detect current profile from symlink, fallback stack
#            2026-03-13 | Added skhd symlink swap for profile separation
function yr --description "yabai + skhd: restart + apply profile"
    argparse 'P/profile=' S/status -- $argv
    or return

    # ── Status Mode ─────────────────────────────────────────────
    if set -q _flag_status
        set_color yellow
        echo "═══ yabai status ═══"
        set_color normal
        set -l layout (yabai -m query --spaces --space 2>/dev/null | jq -r '.type' 2>/dev/null)
        set -l gap (yabai -m config window_gap 2>/dev/null)
        set -l balance (yabai -m config auto_balance 2>/dev/null)
        set -l padding_top (yabai -m config top_padding 2>/dev/null)
        set -l yabai_agents (launchctl list 2>/dev/null | awk '$3 ~ /yabai/ { print $3 ":" $1 }')
        set -l yabai_processes (pgrep -x yabai 2>/dev/null)
        echo "layout      : $layout"
        echo "gap         : $gap"
        echo "padding     : $padding_top"
        echo "auto_balance: $balance"
        if test (count $yabai_agents) -gt 0
            echo "launchd     : "(string join ", " $yabai_agents)
        else
            echo "launchd     : none"
        end
        echo "processes   : "(count $yabai_processes)
        if test (count $yabai_agents) -gt 1; or test (count $yabai_processes) -gt 1
            set_color red
            echo "warning     : multiple yabai owners detected"
            set_color normal
        end

        set_color yellow
        echo ""
        echo "═══ skhd status ═══"
        set_color normal
        set -l active (readlink "$HOME/.config/skhd/modules/active" 2>/dev/null | sed 's|.*/||')
        echo "skhd profile: $active"
        if skhd --status 2>/dev/null
            echo "skhd        : running"
        else
            echo "skhd        : unknown (--status requires skhd.zig)"
        end
        return
    end

    # ── Determine Profile ───────────────────────────────────────
    set -l profile "stack"
    if set -q _flag_profile
        set profile $_flag_profile
    else
        set -l detected (readlink "$HOME/.config/skhd/modules/active" 2>/dev/null | sed 's|.*/||')
        if test -n "$detected"
            set profile "$detected"
        end
    end

    # ── Restart yabai + Apply Profile ───────────────────────────
    # WHY yabai first: if restart fails, don't touch skhd symlink or service.
    if not bash ~/.config/yabai/scripts/yabai-restart.sh "$profile"
        echo "yr: yabai restart failed (profile=$profile)" >&2
        return 1
    end

    # ── Swap skhd modules symlink ───────────────────────────────
    set -l skhd_ok 1
    _swap_skhd_profile "$profile"
    switch $status
        case 0
            skhd --restart-service 2>/dev/null; or set skhd_ok 0
        case 2
            # No skhd profile for this layout (e.g., float) — restart skhd
            # with current bindings intact.
            skhd --restart-service 2>/dev/null; or set skhd_ok 0
            set_color yellow
            echo "yr: no skhd profile for '$profile' — keybindings unchanged"
            set_color normal
        case '*'
            set_color red
            echo "yr: skhd profile swap FAILED for '$profile'" >&2
            set_color normal
            set skhd_ok 0
    end
    # ── Confirm ─────────────────────────────────────────────────
    set -l active (readlink "$HOME/.config/skhd/modules/active" 2>/dev/null | sed 's|.*/||')
    set -l layout (yabai -m query --spaces --space 2>/dev/null | jq -r '.type' 2>/dev/null)
    set -l gap (yabai -m config window_gap 2>/dev/null)
    echo ""
    if test $skhd_ok -eq 1
        set_color yellow
        echo "yr: yabai=$profile  skhd=$active  (restarted)"
        echo "    layout=$layout  gap=$gap"
        set_color normal
    else
        set_color red
        echo "yr: yabai=$profile restarted, but skhd did NOT restart cleanly — hotkeys may be down (skhd=$active)" >&2
        echo "    layout=$layout  gap=$gap" >&2
        set_color normal
        return 1
    end
end
