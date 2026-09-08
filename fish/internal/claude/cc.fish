# path: fish/internal/claude/cc.fish
function cc --description '[claude]: roles --model-{opus-46,opus-47,sonnet}; all immediate-bypass'
    set -l role ""
    set -l passthrough
    set -l options 1

    for arg in $argv
        if test $options -eq 0
            set -a passthrough "$arg"
            continue
        end
        switch $arg
            case --
                set options 0
                set -a passthrough "$arg"
            case --dangerously-skip-permissions
                # The wrapper supplies this once in every role.
            case --model-opus-46
                if test -n "$role"
                    echo "cc: only one --model-* flag" >&2
                    return 2
                end
                set role opus-46
            case --model-opus-47
                if test -n "$role"
                    echo "cc: only one --model-* flag" >&2
                    return 2
                end
                set role opus-47
            case --model-sonnet
                if test -n "$role"
                    echo "cc: only one --model-* flag" >&2
                    return 2
                end
                set role sonnet
            case '--model-*'
                echo "cc: unknown --model-* role; use --model-opus-46, --model-opus-47, or --model-sonnet" >&2
                return 2
            case --model '--model=*' -m '-m=*' '-m*'
                echo "cc: raw --model/-m not allowed; use --model-opus-46, --model-opus-47, or --model-sonnet" >&2
                return 2
            case '*'
                set -a passthrough $arg
        end
    end

    set -lx CLAUDE_CODE_SUBAGENT_MODEL claude-sonnet-4-6

    switch $role
        case opus-46
            claude --model 'claude-opus-4-6[1m]' --dangerously-skip-permissions $passthrough
        case opus-47
            claude --model 'claude-opus-4-7[1m]' --dangerously-skip-permissions $passthrough
        case sonnet
            claude --model claude-sonnet-4-6 --dangerously-skip-permissions $passthrough
        case '*'
            claude --dangerously-skip-permissions $passthrough
    end
end
