# path: ~/.config/fish/internal/skhd/sk.fish
# Description: Restart skhd service (hotkey daemon)
function sk --description "Restart skhd service"
    if skhd --restart-service
        echo "skhd restarted"
    else
        echo "sk: skhd restart failed" >&2
        return 1
    end
end
