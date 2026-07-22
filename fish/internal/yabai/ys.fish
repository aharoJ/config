# path: ~/.config/fish/internal/yabai/ys.fish
# description: Start yabai service.
# date: 2026-02-07

function ys --description "yabai: start service"
    if yabai --start-service
        echo "yabai: service started"
    else
        echo "ys: yabai start failed" >&2
        return 1
    end
end
