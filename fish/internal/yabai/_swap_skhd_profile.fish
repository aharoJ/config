# path: ~/.config/fish/internal/yabai/_swap_skhd_profile.fish
# description: Private helper — swap skhd modules/active symlink to match profile.
#              No output — callers handle their own confirmation messages.
# date: 2026-04-07

function _swap_skhd_profile --description "Swap skhd modules/active symlink"
    set -l profile $argv[1]
    set -l target "$HOME/.config/skhd/modules/$profile"
    # Validate: directory must exist AND have a matching yabai profile script.
    # Rejects non-profile dirs like shared/ that live under modules/.
    if test -d "$target"; and test -f "$HOME/.config/yabai/profiles/yabai-$profile.sh"
        ln -sfn "$target" "$HOME/.config/skhd/modules/active"
        return $status
    end
    return 1
end
