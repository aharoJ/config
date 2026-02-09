# path: ~/.config/fish/functions/skr.fish
# Description: Reload skhd config (hot-reload, no service restart)
function skr --description "Reload skhd config"
    skhd --reload
    echo "skhd config reloaded"
end
