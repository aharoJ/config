# path: ~/.config/fish/internal/yabai/yr.fish
# description: Restart yabai + skhd and apply a layout profile.
# usage:
#   yr                  → restart with stack profile (default)
#   yr -P bsp           → restart with BSP profile
#   yr -P float         → restart with float profile
#   yr --status         → show current yabai + skhd state (no restart)
# date: 2026-02-08
# changelog: 2026-02-08 | Added skhd restart (services are coupled) | ROLLBACK: Remove skhd lines
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
        echo "layout      : $layout"
        echo "gap         : $gap"
        echo "padding     : $padding_top"
        echo "auto_balance: $balance"

        set_color yellow
        echo ""
        echo "═══ skhd status ═══"
        set_color normal
        # skhd.zig supports --status; original skhd does not (harmless if missing)
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
    end

    # ── Restart yabai + Apply Profile ───────────────────────────
    bash ~/.config/yabai/scripts/yabai-restart.sh "$profile"

    # ── Restart skhd (coupled — keybindings must match active layout) ──
    skhd --restart-service 2>/dev/null

    # ── Confirm ─────────────────────────────────────────────────
    set_color yellow
    echo ""
    echo "✅ yabai + skhd restarted (profile: $profile)"
    set -l layout (yabai -m query --spaces --space 2>/dev/null | jq -r '.type' 2>/dev/null)
    set -l gap (yabai -m config window_gap 2>/dev/null)
    echo "   layout : $layout"
    echo "   gap    : $gap"
    set_color normal
end
