# path: ~/.config/fish/internal/skhd/sk.fish
# Description: Restart skhd service (hotkey daemon)
function sk --description "Restart skhd service"
    skhd --restart-service
    echo "skhd restarted"
end
