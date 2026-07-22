# path: ~/.config/fish/internal/yabai/_swap_skhd_profile.fish
# description: Private helper — swap skhd modules/active symlink to match profile.
#              No output — callers handle their own confirmation messages.
# date: 2026-04-07

function _swap_skhd_profile --description "Swap skhd modules/active symlink"
    # Exit codes: 0 = swapped OK; 2 = no matching profile (benign, e.g. float);
    #             1 = matching profile exists but the symlink update FAILED.
    set -l profile $argv[1]
    set -l target "$HOME/.config/skhd/modules/$profile"
    # No matching skhd+yabai profile → not applicable (rejects dirs like shared/).
    if not test -d "$target"; or not test -f "$HOME/.config/yabai/profiles/yabai-$profile.sh"
        return 2
    end
    # Matching profile exists → attempt the swap, propagate the real ln status.
    if ln -sfn "$target" "$HOME/.config/skhd/modules/active"
        return 0
    end
    return 1
end
