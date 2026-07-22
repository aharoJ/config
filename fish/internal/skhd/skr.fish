# path: ~/.config/fish/internal/skhd/skr.fish
# Description: Reload skhd config (hot-reload, no service restart)
function skr --description "Reload skhd config"
    if skhd --reload
        echo "skhd config reloaded"
    else
        echo "skr: skhd reload failed" >&2
        return 1
    end
end
