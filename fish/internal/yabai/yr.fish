#!/usr/bin/env fish
# Restart Yabai cleanly and re-apply the selected mode (stack | bsp)
# Usage:
#   yr                 # infer mode from SKHD symlink
#   yr -P stack        # force stack (auto hard-fix Hammerspoon)
#   yr -P bsp          # force bsp (re-balance, no HS reload)
#   yr --status        # print current mode/layout/links (no changes)

function yr --description "yabai: restart service (mode-aware, single command)"
    argparse 'P/profile=' S/status -- $argv
    or return

    if set -q _flag_status
        set_color yellow
        echo "=== Yabai/SKHD Mode Status ==="
        set_color normal
        set layout (yabai -m query --spaces --space | jq -r '.type' 2>/dev/null)
        set gap (yabai -m config window_gap 2>/dev/null)
        set skhdrc_target (readlink ~/.config/skhd/skhdrc 2>/dev/null)
        if test -z "$skhdrc_target"
            set skhdrc_target "(not a symlink or missing)"
        end
        echo "Yabai layout : $layout"
        echo "Window gap   : $gap"
        echo "skhdrc →     : $skhdrc_target"
        echo "Current mode : "(string replace -r '^.*/(.*)\.skhd$' '$1' -- $skhdrc_target)
        return
    end

    # 1️⃣ Decide mode (either user-specified or inferred from SKHD symlink)
    set -l mode ""
    if set -q _flag_profile
        set mode $_flag_profile
    else
        set -l target (readlink ~/.config/skhd/skhdrc 2>/dev/null)
        if test -n "$target"
            if string match -rq 'bsp\.skhd$' -- $target
                set mode bsp
            else if string match -rq 'stack\.skhd$' -- $target
                set mode stack
            end
        end
    end
    if test -z "$mode"
        set mode stack
    end

    # 2️⃣ Always perform the stack hard-fix automatically when mode=stack
    set -l reload_flag ""
    if test "$mode" = stack
        set reload_flag --reload-hs
    end

    # 3️⃣ Run restart+reapply+sync
    ~/.scripts/yabai-restart-clean.sh "$mode" $reload_flag

    # 4️⃣ Friendly status after
    set_color yellow
    echo ""
    echo "✅ Restart complete (mode: $mode)"
    set layout (yabai -m query --spaces --space | jq -r '.type' 2>/dev/null)
    set gap (yabai -m config window_gap 2>/dev/null)
    echo "   Yabai layout : $layout"
    echo "   Window gap   : $gap"
    echo "   skhdrc →     : "(readlink ~/.config/skhd/skhdrc 2>/dev/null)
    set_color normal
end
