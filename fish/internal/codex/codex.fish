function codex --description 'Codex CLI model presets: --model-gpt-5-5, --model-gpt-5-3-codex'
    set -l preset ""
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
            case --model-gpt-5-5 --model-lead
                if test -n "$preset"
                    echo 'codex: only one model preset flag may be used' >&2
                    return 2
                end
                if test "$arg" = --model-lead
                    echo 'codex: --model-lead is deprecated; use --model-gpt-5-5' >&2
                end
                set preset gpt-5.5
            case --model-gpt-5-3-codex --model-audit
                if test -n "$preset"
                    echo 'codex: only one model preset flag may be used' >&2
                    return 2
                end
                if test "$arg" = --model-audit
                    echo 'codex: --model-audit is deprecated; use --model-gpt-5-3-codex' >&2
                end
                set preset gpt-5.3-codex
            case --model '--model=*' -m '-m*'
                set raw_model 1
                set -a passthrough "$arg"
            case '*'
                set -a passthrough $arg
        end
    end

    if test -n "$preset"; and test $raw_model -eq 1
        echo 'codex: raw --model/-m cannot be combined with a model preset' >&2
        return 2
    end

    if test -n "$preset"
        _agent_limit codex -m "$preset" --dangerously-bypass-approvals-and-sandbox $passthrough
    else
        _agent_limit codex --dangerously-bypass-approvals-and-sandbox $passthrough
    end
end

complete -c codex -l model-gpt-5-5 -d 'Select the gpt-5.5 model preset'
complete -c codex -l model-gpt-5-3-codex -d 'Select the gpt-5.3-codex model preset'
