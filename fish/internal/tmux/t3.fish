# path: ~/.config/fish/internal/tmux/t3.fish
# description: Set up claude, notes, and codex tmux windows in the current directory, or custom named windows.
# patched: 2026-10-10 restore claude/notes/codex as the default; drop --legacy
# date: 2026-10-05

function t3 --description 'tmux: set up claude, notes, and codex windows'
    argparse --name=t3 h/help 'focus=' -- $argv
    or return $status
    if set -q _flag_help
        echo 'usage: t3 [--focus <name>] [window names...]'
        echo '       no names: claude notes codex, focus claude'
        return 0
    end
    if test (count $_flag_focus) -gt 1
        echo 't3: --focus may be specified only once' >&2
        return 2
    end
    for name in $argv $_flag_focus
        if not string match -qr '^[A-Za-z0-9_][A-Za-z0-9_-]*$' -- "$name"
            echo 't3: window names must contain only letters, digits, underscores or hyphens' >&2
            return 2
        end
    end
    set -l requested $argv
    set -l focus $_flag_focus
    set -l default 0
    if test (count $requested) -eq 0
        set default 1
        set requested claude notes codex
        if test (count $focus) -eq 0
            set focus claude
        end
    end
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
        if test $default -eq 1; and not contains -- claude $names
            tmux rename-window $target claude
            or return $status
        end
    else
        set session (string replace -a -r '[.:]' _ -- (path basename "$PWD"))
        if not tmux has-session -t "=$session" 2>/dev/null
            if test (count $focus) -gt 0; and not contains -- "$focus" $requested
                echo "t3: focus window '$focus' is not a requested window" >&2
                return 2
            end
            tmux new-session -d -s "$session" -n "$requested[1]" -c "$PWD"
            or return $status
        end
        set session (tmux display-message -p -t "=$session:" '#{session_id}')
        or return $status
    end

    set -l names (tmux list-windows -t "$session" -F '#{window_name}')
    or return $status
    if test (count $focus) -gt 0; and not contains -- "$focus" $names $requested
        echo "t3: focus window '$focus' is not an existing or requested window" >&2
        return 2
    end
    for name in $requested
        if not contains -- "$name" $names
            tmux new-window -d -t "$session:" -n "$name" -c "$PWD"
            or return $status
            set -a names "$name"
        end
    end
    if test (count $focus) -gt 0
        tmux select-window -t "$session:=$focus"
        or return $status
    end
    if test $inside -eq 0
        tmux attach-session -t "$session"
    end
end

complete -c t3 -f
complete -c t3 -l help -s h -d 'Show usage'
complete -c t3 -l focus -r -d 'Select an existing or requested window'
