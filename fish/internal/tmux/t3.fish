# path: ~/.config/fish/internal/tmux/t3.fish
# description: Set up claude, notes, and codex tmux windows in the current directory.
# date: 2026-10-05

function t3 --description 'tmux: set up claude, notes, and codex windows'
    set -l session
    set -l inside 0
    if set -q TMUX; and test -n "$TMUX"
        set inside 1
        set -l target
        if set -q TMUX_PANE; and test -n "$TMUX_PANE"
            set target -t "$TMUX_PANE"
        end
        set session (tmux display-message -p $target '#{session_id}')
        or return $status
        set -l names (tmux list-windows -t "$session" -F '#{window_name}')
        or return $status
        if not contains -- claude $names
            tmux rename-window $target claude
            or return $status
        end
    else
        set session (string replace -a -r '[.:]' _ -- (path basename "$PWD"))
        if not tmux has-session -t "=$session" 2>/dev/null
            tmux new-session -d -s "$session" -n claude -c "$PWD"
            or return $status
        end
        set session (tmux display-message -p -t "=$session:" '#{session_id}')
        or return $status
    end

    set -l names (tmux list-windows -t "$session" -F '#{window_name}')
    or return $status
    for name in claude notes codex
        if not contains -- "$name" $names
            tmux new-window -d -t "$session:" -n "$name" -c "$PWD"
            or return $status
        end
    end
    tmux select-window -t "$session:=claude"
    or return $status
    if test $inside -eq 0
        tmux attach-session -t "$session"
    end
end
