# path: fish/internal/claude/cc.fish
function cc --description '[claude]: roles --model-{opus-46,opus-47,sonnet}; opus=plan-first, sonnet=immediate-bypass'
    set -l role ""
    set -l passthrough

    for arg in $argv
        switch $arg
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
            claude --model 'claude-opus-4-6[1m]' --permission-mode plan --allow-dangerously-skip-permissions $passthrough
        case opus-47
            set -lx CLAUDE_CODE_EFFORT_LEVEL xhigh
            claude --model 'claude-opus-4-7[1m]' --permission-mode plan --allow-dangerously-skip-permissions $passthrough
        case sonnet
            set -lx CLAUDE_CODE_EFFORT_LEVEL low
            set -lx CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING 1
            set -lx MAX_THINKING_TOKENS 4000
            claude --model claude-sonnet-4-6 --dangerously-skip-permissions $passthrough
        case '*'
            claude --permission-mode plan --allow-dangerously-skip-permissions $passthrough
    end
end
