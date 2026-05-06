# path: ~/.config/fish/internal/tmux/tai.fish
# description: Spawn AI agent tmux windows in the current directory.

function __tai_usage
    echo "usage: tai [codex|gemini|cc|deepseek|all] [agent args...]"
    echo "       tai        # same as: tai all"
end

function __tai_window_name
    set -l agent $argv[1]
    echo "$agent"
end

function __tai_spawn
    set -l agent $argv[1]
    set -l launch_dir $argv[2]
    set -l window_name (__tai_window_name "$agent" "$launch_dir")
    set -l fish_bin (command -s fish)

    if test -z "$fish_bin"
        echo "tai: fish not found" >&2
        return 1
    end

    set -l parts $agent
    if test "$agent" = codex
        set parts codex --model-audit
    else if test "$agent" = cc
        set parts cc --model-sonnet
    end
    for arg in $argv[3..-1]
        set -a parts (string escape -- $arg)
    end
    set -l commandline (string join ' ' -- $parts)

    set -l pane (tmux new-window -P -F '#{pane_id}' -c "$launch_dir" -n "$window_name" "$fish_bin -l")
    or return $status

    tmux send-keys -t "$pane" "$commandline" Enter
    echo "tai: $window_name -> $commandline"
end

function tai --description 'tmux: spawn AI agent window in current directory'
    if not set -q TMUX
        echo "tai: run this inside tmux" >&2
        return 1
    end

    set -l agents gemini codex cc deepseek

    if test (count $argv) -eq 0
        set argv all
    end

    set -l target $argv[1]
    set -e argv[1]

    set -l targets
    switch "$target"
        case all
            if test (count $argv) -gt 0
                echo "tai: 'all' does not accept extra agent args" >&2
                return 2
            end
            set targets $agents
        case codex gemini cc deepseek
            set targets $target
        case '*'
            echo "tai: unknown agent '$target'" >&2
            __tai_usage >&2
            return 2
    end

    set -l launch_dir (pwd)

    for agent in $targets
        if not fish -lc "type -q $agent"
            echo "tai: '$agent' is not available in fish" >&2
            return 1
        end
    end

    for agent in $targets
        __tai_spawn "$agent" "$launch_dir" $argv
        or return $status
    end
end

complete -c tai -f
complete -c tai -n "not __fish_seen_subcommand_from codex gemini cc deepseek all" -a "codex gemini cc deepseek all"
