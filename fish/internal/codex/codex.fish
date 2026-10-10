function __codex_legacy_preset
    set -l today (command date +%Y%m%d)
    or begin
        echo "codex: cannot check preset migration deadline; use $argv[2]" >&2
        return 2
    end
    if not string match -qr '^[0-9]{8}$' -- "$today"
        echo "codex: cannot check preset migration deadline; use $argv[2]" >&2
        return 2
    end
    if test "$today" -ge 20261101
        echo "codex: $argv[1] retired on 2026-11-01; use $argv[2]" >&2
        return 2
    end
    echo "codex: $argv[1] is deprecated until 2026-11-01; use $argv[2]" >&2
end

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
                    __codex_legacy_preset "$arg" --model-gpt-5-5
                    or return $status
                end
                set preset gpt-5.5
            case --model-gpt-5-3-codex --model-audit
                if test -n "$preset"
                    echo 'codex: only one model preset flag may be used' >&2
                    return 2
                end
                if test "$arg" = --model-audit
                    __codex_legacy_preset "$arg" --model-gpt-5-3-codex
                    or return $status
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
