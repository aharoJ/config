# path: ~/.config/fish/internal/yabai/yp.fish
# description: Switch yabai profile without restarting the service.
#              Faster than yr — just applies layout/padding/gap changes.
# usage:
#   yp stack            → switch to stack mode
#   yp bsp              → switch to BSP mode
#   yp float            → switch to float mode
# date: 2026-02-07

function yp --description "yabai: switch profile (no restart)"
    set -l profile $argv[1]

    if test -z "$profile"
        echo "usage: yp [stack|bsp|float]"
        return 1
    end

    set -l script "$HOME/.config/yabai/profiles/yabai-$profile.sh"

    if not test -f "$script"
        echo "error: unknown profile '$profile'"
        echo "available: stack, bsp, float"
        return 1
    end

    bash "$script"

    set_color yellow
    echo "✅ profile applied: $profile"
    set_color normal
end
