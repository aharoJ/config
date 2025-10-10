#!/usr/bin/env fish
# /Users/aharoj/.config/fish/internal/yabai/yp.fish
function yp --description 'Switch Yabai tiling modes manually (stack | bsp)'
    argparse 'P/profile=' -- $argv
    or return

    # default mode
    set -l mode stack

    if set -q _flag_profile
        set mode $_flag_profile
    end

    # Paths to your configs
    set -l base ~/.config/yabai/scripts/profiles
    set -l stack_conf $base/stack.sh
    set -l bsp_conf $base/bsp.sh

    # Apply mode
    switch $mode
        case stack
            echo ""
            set_color green
            echo "🧱 Applying Yabai mode: STACK (layered / vertical stack)"
            set_color normal
            bash $stack_conf
        case bsp
            echo ""
            set_color cyan
            echo "🧩 Applying Yabai mode: BSP (binary space partitioning)"
            set_color normal
            bash $bsp_conf
        case '*'
            set_color red
            echo "❌ Unknown mode: $mode"
            set_color normal
            echo "Usage: yp -P [stack|bsp]"
            return 1
    end
    # Optional: store current profile for reference
    echo $profile > ~/.config/yabai/scripts/profiles/.current_profile

    # Status message
    echo ""
    set_color yellow
    echo "✅ Yabai mode switched → $mode"

    # 🪄 live layout summary
    set layout (yabai -m query --spaces --space | jq -r '.type')
    set gap (yabai -m query --spaces --space | jq -r '.gap')
    echo "   Layout: $layout"
    echo "   Window Gap: $gap"
    set_color normal
end
