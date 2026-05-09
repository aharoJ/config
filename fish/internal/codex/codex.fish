function codex --description "Codex CLI with role shortcuts: --model-lead (5.5 xhigh), --model-audit (5.3-codex xhigh)"
    set -l role ""
    set -l passthrough

    for arg in $argv
        switch $arg
            case --model-lead
                if test -n "$role"
                    echo "codex: only one --model-* role flag may be used" >&2
                    return 2
                end
                set role lead
            case --model-audit
                if test -n "$role"
                    echo "codex: only one --model-* role flag may be used" >&2
                    return 2
                end
                set role audit
            case '*'
                set -a passthrough $arg
        end
    end

    switch $role
        case lead
            command codex -m gpt-5.5 -c model_reasoning_effort='"xhigh"' --dangerously-bypass-approvals-and-sandbox $passthrough
        case audit
            command codex -m gpt-5.3-codex -c model_reasoning_effort='"xhigh"' --dangerously-bypass-approvals-and-sandbox $passthrough
        case '*'
            command codex --dangerously-bypass-approvals-and-sandbox $passthrough
    end
end
