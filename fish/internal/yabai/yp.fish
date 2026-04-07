# path: ~/.config/fish/internal/yabai/yp.fish
# description: Switch yabai profile + skhd keybindings without restarting services.
#              Swaps the skhd modules/active symlink to match the layout profile,
#              then reloads skhd so the correct bindings take effect.
# usage:
#   yp stack            → switch to stack mode (yabai + skhd)
#   yp bsp              → switch to BSP mode (yabai + skhd)
#   yp float            → switch to float mode (yabai only, skhd stays current)
# date: 2026-02-07
# changelog: 2026-04-07 | D-01: Extract symlink swap to _swap_skhd_profile helper
#            2026-03-13 | Added skhd symlink swap + reload for profile separation

function yp --description "yabai + skhd: switch profile (no restart)"
    set -l profile $argv[1]

    if test -z "$profile"
        echo "usage: yp [stack|bsp|float]"
        return 1
    end

    # ── Validate yabai profile ─────────────────────────────────────
    set -l script "$HOME/.config/yabai/profiles/yabai-$profile.sh"

    if not test -f "$script"
        echo "error: unknown profile '$profile'"
        echo "available: stack, bsp, float"
        return 1
    end

    # ── Apply yabai profile ────────────────────────────────────────
    if not bash "$script"
        echo "yp: yabai profile '$profile' failed to apply" >&2
        return 1
    end

    # ── Swap skhd modules symlink ──────────────────────────────────
    # Only swap if skhd has a matching profile directory.
    # Float mode has no dedicated skhd profile — keeps current bindings.
    if _swap_skhd_profile "$profile"
        skhd -r 2>/dev/null
        set_color yellow
        echo "yp: yabai=$profile  skhd=$profile"
        set_color normal
    else
        set_color yellow
        echo "yp: yabai=$profile  skhd=unchanged (no skhd profile for '$profile')"
        set_color normal
    end
end
