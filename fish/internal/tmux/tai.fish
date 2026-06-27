# path: ~/.config/fish/internal/tmux/tai.fish
# description: Spawn AI agent tmux windows in the current directory.

function __tai_usage
    echo "usage: tai [codex|gemini|cc|deepseek|mimo|all] [agent args...]"
    echo "       tai        # same as: tai all"
end

function __tai_window_name
    set -l agent $argv[1]
    echo "$agent"
end

# Resolve an agent label to the fish command that backs it. Most agents are
# their own command; mimo runs through the openrouter wrapper, and gemini now
# runs through agy (Antigravity CLI) since gemini-cli was discontinued.
function __tai_command
    switch $argv[1]
        case mimo
            echo openrouter
        case gemini
            echo agy
        case '*'
            echo $argv[1]
    end
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
    else if test "$agent" = gemini
        set parts agy --dangerously-skip-permissions
    else if test "$agent" = mimo
        set parts openrouter --mimo-v2.5
    end
    set -l skip_next 0
    for arg in $argv[3..-1]
        if test "$skip_next" -eq 1
            set skip_next 0
            continue
        end
        if test "$agent" = gemini
            # Drop stale gemini-cli flags (agy rejects them) and any user dupe of
            # the forced bypass. --sandbox stays stripped to keep this slot
            # YOLO/no-sandbox by design; --model passes through for overrides.
            switch "$arg"
                case --approval-mode --policy --admin-policy
                    set skip_next 1
                    continue
                case '--approval-mode=*' --yolo -y --skip-trust --sandbox -s --no-sandbox '--sandbox=*' '--policy=*' '--admin-policy=*' --dangerously-skip-permissions
                    continue
            end
        end
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

    set -l agents gemini codex cc deepseek mimo

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
        case codex gemini cc deepseek mimo
            set targets $target
        case '*'
            echo "tai: unknown agent '$target'" >&2
            __tai_usage >&2
            return 2
    end

    set -l launch_dir (pwd)

    for agent in $targets
        set -l cmd (__tai_command $agent)
        if not fish -lc "type -q $cmd"
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
complete -c tai -n "not __fish_seen_subcommand_from codex gemini cc deepseek mimo all" -a "codex gemini cc deepseek mimo all"
