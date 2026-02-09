# path: ~/.config/fish/functions/sk.fish
# Description: Restart skhd service (hotkey daemon)
function sk --description "Restart skhd service"
    skhd --restart-service
    echo "skhd restarted"
end
