# path: ~/.config/fish/internal/yabai/yk.fish
# description: Stop yabai service.
# date: 2026-02-07

function yk --description "yabai: stop service"
    if yabai --stop-service
        echo "yabai: service stopped"
    else
        echo "yk: yabai stop failed" >&2
        return 1
    end
end
