# path: ~/.config/fish/internal/tmux/tai.fish
# description: Spawn AI agent tmux windows in the current directory.
# patched: panel seats on low effort; fable on Sonnet 5.5 medium, astra on gpt-6-luna
# date: 2026-10-03

# tai all: window name | exact command. Comment a row to disable only that panel slot.
function __tai_panel
    printf '%s\n' 'gemini|agy --dangerously-skip-permissions --effort low'
    printf '%s\n' 'astra|codex -m gpt-6-luna -c model_reasoning_effort="low"'
    printf '%s\n' 'fable|cc --settings {"model":"claude-sonnet-5-5"} --effort medium'
    printf '%s\n' 'deepseek|deepseek --settings {"model":"deepseek-flash"} --effort low'
    # printf '%s\n' 'kimi|kimi --auto'
    # printf '%s\n' 'mimo|openrouter --mimo-v2.5'
end
# Kimi exposes no native effort flag. Its wrapper must use --auto, not --yolo.

function __tai_usage
    echo "usage: tai [--session <session>] [codex|gemini|cc|deepseek|mimo|kimi|all] [agent args...]"
    echo "       tai [--session <session>] seat <gemini|astra|fable|deepseek> [agent args...]"
    echo "       tai        # same as: tai all"
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

# Wrappers own bypass; agy needs tai's flag. Native CLIs own their other policy
# flags for Claude/Kimi. Codex/agy policy precedence is unproved: reject their
# installed native policy options. OpenRouter yields to caller approval flags.
function __tai_validate
    set -l agent $argv[1]
    set -e argv[1]
    set -l approvals 0
    set -l separator 0
    while set -q argv[1]
        set -l arg "$argv[1]"
        set -e argv[1]
        # OpenRouter's existing wrapper scans even after --.
        if test "$arg" = --; and test "$agent" != mimo
            break
        end
        test "$arg" = --; and set separator 1
        switch "$agent:$arg"
            case 'codex:--dangerously-bypass-approvals-and-sandbox' 'gemini:--dangerously-skip-permissions' 'gemini:--dangerously-skip-permissions=*'
                echo "tai: bypass/YOLO is already enabled for '$agent'; omit '$arg'" >&2
                return 2
            case 'codex:--ask-for-approval' 'codex:--ask-for-approval=*' 'codex:-a' 'codex:-a=*' 'codex:-anever' 'codex:-aon-request' 'codex:--sandbox' 'codex:--sandbox=*' 'codex:-s' 'codex:-s=*' 'codex:-sread-only' 'codex:-sworkspace-write' 'codex:-sdanger-full-access' 'codex:--approve-for-me' 'gemini:--sandbox' 'gemini:--sandbox=*' 'gemini:--mode' 'gemini:--mode=*'
                echo "tai: '$arg' has unverified precedence against '$agent' bypass; launch the wrapper directly to choose another policy" >&2
                return 2
            case 'codex:-c*' 'codex:--config' 'codex:--config=*'
                set -l value (string replace -r -- '^(-c=?|--config=)' '' "$arg")
                if contains -- "$arg" -c --config
                    set value "$argv[1]"
                end
                set -l key (string split -m 1 = -- "$value")[1]
                set key (string replace -ar -- '["[:space:]]' '' "$key")
                if string match -qr '^(approval_policy|sandbox_mode|sandbox_permissions|permission_profile|default_permissions|permissions)(\.|$)' -- "$key"
                    echo "tai: Codex policy config '$key' has unverified precedence against bypass" >&2
                    return 2
                end
            case 'mimo:--approval-mode' 'mimo:--approval-mode=*' 'mimo:--yolo' 'mimo:-y'
                set approvals (math $approvals + 1)
                set -l mode yolo
                if test "$arg" = --approval-mode
                    set mode "$argv[1]"
                    set -e argv[1]
                else if string match -q -- '--approval-mode=*' "$arg"
                    set mode (string replace -- '--approval-mode=' '' "$arg")
                end
                if test "$mode" != yolo; or test $approvals -gt 1; or test $separator -eq 1
                    echo "tai: Mimo requires one YOLO approval mode; omit '$arg' and use the wrapper default" >&2
                    return 2
                end
        end
    end
    return 0
end

# Leading --env=KEY=VALUE args become tmux window env, since send-keys cannot
# carry the caller's environment into the new pane.
function __tai_session
    set -l session "$argv[1]"
    if test -z "$session"
        if not string match -qr '^%[0-9]+$' -- "$TMUX_PANE"
            echo "tai: --session or a valid TMUX_PANE is required" >&2
            return 1
        end
        set -l identity (tmux display-message -p -t "$TMUX_PANE" '#{pane_id}|#{session_name}')
        or return 1
        set -l fields (string split -m 1 '|' -- "$identity")
        if test (count $fields) -ne 2; or test "$fields[1]" != "$TMUX_PANE"
            echo "tai: cannot resolve caller session" >&2
            return 1
        end
        set session "$fields[2]"
    end
    if test -z "$session"; or not tmux has-session -t "=$session"
        echo "tai: session '$session' does not exist" >&2
        return 1
    end
    printf '%s\n' "$session"
end

function __tai_spawn
    set -l window_name $argv[1]
    set -l launch_dir $argv[2]
    set -e argv[1..2]
    set -l fish_bin (command -s fish)

    if test -z "$fish_bin"
        echo "tai: fish not found" >&2
        return 1
    end

    set -l env_args
    set -l session
    while set -q argv[1]
        switch "$argv[1]"
            case '--env=*'
                set -a env_args -e (string replace -- '--env=' '' "$argv[1]")
            case '--session=*'
                set session (string replace -- '--session=' '' "$argv[1]")
            case '*'
                break
        end
        set -e argv[1]
    end
    set session (__tai_session "$session")
    or return $status

    set -l parts
    for arg in $argv
        set -a parts (string escape -- "$arg")
    end
    set -l commandline (string join ' ' -- $parts)

    set -l pane (tmux new-window -t "=$session:" -P -F '#{pane_id}' -c "$launch_dir" -n "$window_name" $env_args "$fish_bin -l")
    or return $status

    tmux send-keys -t "$pane" "$commandline" Enter
    or return $status
    echo "tai: $window_name -> $commandline"
end

# tai seat: one isolated agentic audit seat, launched from inside its exact
# /private/tmp/review-protocol-*-audit-r*-agentic-*-cli folder. The folder is
# pre-trusted for that CLI only. Extra args replace the default model/effort
# args; the isolation flags are always appended.
function __tai_seat
    set -l session $argv[1]
    set -l seat $argv[2]
    set -e argv[1..2]
    set -l launch_dir (pwd -P)
    set -l trust_kind
    set -l parts
    set -l defaults
    set -l isolation
    switch "$seat"
        case gemini
            set trust_kind agy
            set parts agy --dangerously-skip-permissions
            set defaults --effort low
            __tai_validate gemini $argv
            or return $status
        case astra
            set trust_kind codex
            set parts --env=CODEX_HOME=$HOME/.local/state/codex-panel-home codex
            __tai_validate codex $argv
            or return $status
        case fable
            set trust_kind claude
            set parts cc
            set defaults --settings '{"model":"claude-sonnet-5-5"}' --effort medium
            set isolation --safe-mode --disable-slash-commands
        case deepseek
            set trust_kind deepseek
            set parts deepseek
            set defaults --settings '{"model":"deepseek-flash"}' --effort low
            set isolation --bare --disable-slash-commands
        case '*'
            echo "tai: seat must be one of gemini astra fable deepseek" >&2
            return 2
    end

    set -l args $defaults
    if test (count $argv) -gt 0
        set args
        for arg in $argv
            contains -- "$arg" $isolation; or set -a args "$arg"
        end
    end

    $HOME/.config/tmux/tools/panel-seat-trust $trust_kind "$launch_dir"
    or return $status

    __tai_spawn "$seat" "$launch_dir" "--session=$session" $parts $args $isolation
end

function tai --description 'tmux: spawn AI agent window in current directory'
    set -l session
    set -l remaining
    while set -q argv[1]
        switch "$argv[1]"
            case --
                set -a remaining $argv
                break
            case --session '--session=*'
                if test -n "$session"
                    echo "tai: --session may be specified only once" >&2
                    return 2
                end
                if test "$argv[1]" = --session
                    if not set -q argv[2]; or test -z "$argv[2]"
                        echo "tai: --session requires a session name" >&2
                        return 2
                    end
                    set session "$argv[2]"
                    set -e argv[1]
                else
                    set session (string replace -- '--session=' '' "$argv[1]")
                    if test -z "$session"
                        echo "tai: --session requires a session name" >&2
                        return 2
                    end
                end
            case '*'
                set -a remaining "$argv[1]"
        end
        set -e argv[1]
    end
    set argv $remaining
    set session (__tai_session "$session")
    or return $status

    set -l panel (__tai_panel)

    if test (count $argv) -eq 0
        set argv all
    end

    set -l target $argv[1]
    set -e argv[1]

    if test "$target" = seat
        if test (count $argv) -eq 0
            __tai_usage >&2
            return 2
        end
        __tai_seat "$session" $argv
        return $status
    end

    set -l targets
    switch "$target"
        case all
            if test (count $argv) -gt 0
                echo "tai: 'all' does not accept extra agent args" >&2
                return 2
            end
            for row in $panel
                set -l fields (string split -m 1 '|' -- "$row")
                set -a targets (string split -m 1 ' ' -- "$fields[2]")[1]
            end
        case codex gemini cc deepseek mimo kimi
            set targets $target
        case '*'
            echo "tai: unknown agent '$target'" >&2
            __tai_usage >&2
            return 2
    end

    set -l launch_dir (pwd)

    __tai_validate "$target" $argv
    or return $status

    for agent in $targets
        set -l cmd (__tai_command $agent)
        if not fish -lc "type -q $cmd"
            echo "tai: '$agent' is not available in fish" >&2
            return 1
        end
    end

    if test "$target" = all
        for row in $panel
            set -l fields (string split -m 1 '|' -- "$row")
            __tai_spawn "$fields[1]" "$launch_dir" "--session=$session" (string split ' ' -- "$fields[2]")
            or return $status
        end
    else
        set -l parts (__tai_command "$target")
        set -l window_name "$target"
        switch "$target"
            case codex
                set window_name astra
            case cc
                set window_name fable
            case gemini
                set -a parts --dangerously-skip-permissions
        end
        __tai_spawn "$window_name" "$launch_dir" "--session=$session" $parts $argv
        or return $status
    end
end

complete -c tai -e
complete -c tai -f
complete -c tai -l session -r -d 'Explicit destination tmux session'
complete -c tai -n "not __fish_seen_subcommand_from codex gemini cc deepseek mimo kimi all seat" -a "codex gemini cc deepseek mimo kimi all seat"
complete -c tai -n "__fish_seen_subcommand_from seat" -a "gemini astra fable deepseek"
