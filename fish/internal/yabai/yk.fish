# path: ~/.config/fish/internal/yabai/yk.fish
# description: Stop yabai service.
# date: 2026-02-07

function yk --description "yabai: stop service"
    yabai --stop-service
    echo "yabai: service stopped"
end
