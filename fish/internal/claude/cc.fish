# path: fish/internal/claude/cc.fish
function cc --description '[claude]: plan-first with bypass; --model-{opus-46,opus-47,sonnet,haiku-swarm,swarm}'
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
            case --model-haiku-swarm
                if test -n "$role"
                    echo "cc: only one --model-* flag" >&2
                    return 2
                end
                set role haiku-swarm
            case --model-swarm
                if test -n "$role"
                    echo "cc: only one --model-* flag" >&2
                    return 2
                end
                set role swarm
            case '*'
                set -a passthrough $arg
        end
    end

    switch $role
        case opus-46
            claude --model 'claude-opus-4-6[1m]' --permission-mode plan --allow-dangerously-skip-permissions $passthrough
        case opus-47
            set -lx CLAUDE_CODE_EFFORT_LEVEL xhigh
            claude --model 'claude-opus-4-7[1m]' --permission-mode plan --allow-dangerously-skip-permissions $passthrough
        case sonnet
            set -lx CLAUDE_CODE_EFFORT_LEVEL low
            set -lx MAX_THINKING_TOKENS 4000
            claude --model claude-sonnet-4-6 --dangerously-skip-permissions $passthrough
        case haiku-swarm
            set -lx CLAUDE_CODE_SUBAGENT_MODEL claude-haiku-4-5-20251001
            set -lx CLAUDE_CODE_EFFORT_LEVEL low
            set -lx MAX_THINKING_TOKENS 4000
            claude --model claude-sonnet-4-6 --dangerously-skip-permissions $passthrough
        case swarm
            set -lx CLAUDE_CODE_SUBAGENT_MODEL claude-haiku-4-5-20251001
            set -lx CLAUDE_CODE_EFFORT_LEVEL low
            set -lx MAX_THINKING_TOKENS 4000
            claude --model claude-haiku-4-5-20251001 --dangerously-skip-permissions $passthrough
        case '*'
            claude --permission-mode plan --allow-dangerously-skip-permissions $passthrough
    end
end
