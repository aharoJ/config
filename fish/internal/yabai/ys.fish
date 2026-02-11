# path: ~/.config/fish/internal/yabai/ys.fish
# description: Start yabai service.
# date: 2026-02-07

function ys --description "yabai: start service"
    yabai --start-service
    echo "yabai: service started"
end
