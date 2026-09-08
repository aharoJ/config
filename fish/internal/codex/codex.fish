function codex --description "Codex CLI with model shortcuts: --model-lead (5.5), --model-audit (5.3-codex)"
    set -l role ""
    set -l passthrough
    set -l options 1
    set -l raw_model 0

    for arg in $argv
        if test $options -eq 0
            set -a passthrough "$arg"
            continue
        end
        switch $arg
            case --
                set options 0
                set -a passthrough "$arg"
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
            case --model '--model=*' -m '-m*'
                set raw_model 1
                set -a passthrough "$arg"
            case '*'
                set -a passthrough $arg
        end
    end

    if test -n "$role"; and test $raw_model -eq 1
        echo "codex: raw --model/-m cannot be combined with a --model-lead/--model-audit role" >&2
        return 2
    end

    switch $role
        case lead
            _agent_limit codex -m gpt-5.5 --dangerously-bypass-approvals-and-sandbox $passthrough
        case audit
            _agent_limit codex -m gpt-5.3-codex --dangerously-bypass-approvals-and-sandbox $passthrough
        case '*'
            _agent_limit codex --dangerously-bypass-approvals-and-sandbox $passthrough
    end
end
