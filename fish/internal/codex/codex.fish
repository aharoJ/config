function __codex_valid_date
    string match -qr '^[0-9]{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$' -- "$argv[1]"
    or return 1
    set -l year (string sub -s 1 -l 4 -- "$argv[1]")
    test "$year" -gt 0
    or return 1
    set -l month (math (string sub -s 5 -l 2 -- "$argv[1]"))
    set -l day (string sub -s 7 -l 2 -- "$argv[1]")
    set -l days 31 28 31 30 31 30 31 31 30 31 30 31
    if test (math "$year % 4") -eq 0; and begin
            test (math "$year % 100") -ne 0; or test (math "$year % 400") -eq 0
        end
        set days[2] 29
    end
    test "$day" -le "$days[$month]"
end

function __codex_legacy_preset
    set -l today (command date +%Y%m%d)
    or begin
        echo "codex: cannot check preset migration deadline; use $argv[2]" >&2
        return 2
    end
    if not __codex_valid_date "$today"
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
    set -l value_next 0
    set -l image_values 0
    set -l command_seen 0
    set -l local_launch 1
    set -l explicit_local 0

    for arg in $argv
        if test $options -eq 0
            set -a passthrough "$arg"
            continue
        end
        if test $value_next -eq 1
            set value_next 0
            set -a passthrough "$arg"
            continue
        end
        if test $image_values -eq 1
            if not string match -q -- '-*' "$arg"
                set -a passthrough "$arg"
                continue
            end
            set image_values 0
        end
        if test $command_seen -eq 0; and not string match -q -- '-*' "$arg"
            set command_seen 1
            switch $arg
                case resume fork
                case '*'
                    set local_launch 0
            end
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
                if contains -- "$arg" --model -m
                    set value_next 1
                end
                set -a passthrough "$arg"
            case --no-daemon
                set explicit_local 1
            case --dangerously-bypass-approvals-and-sandbox
                # Always added below; a second copy makes codex exit.
            case --remote --remote-auth-token-env
                set local_launch 0
                set value_next 1
                set -a passthrough "$arg"
            case '--remote=*' '--remote-auth-token-env=*'
                set local_launch 0
                set -a passthrough "$arg"
            case -i --image
                set image_values 1
                set -a passthrough "$arg"
            case '--image=*' '-i*'
                set -a passthrough "$arg"
            case -c --config -p --profile -s --sandbox -a --ask-for-approval -C --cd --add-dir --enable --disable --local-provider
                set value_next 1
                set -a passthrough "$arg"
            case '*'
                set -a passthrough $arg
        end
    end

    if test -n "$preset"; and test $raw_model -eq 1
        echo 'codex: raw --model/-m cannot be combined with a model preset' >&2
        return 2
    end

    set -l launch_options
    if test $local_launch -eq 1; or test $explicit_local -eq 1
        set launch_options --no-daemon
    end
    if test -n "$preset"
        _agent_limit codex $launch_options -m "$preset" --dangerously-bypass-approvals-and-sandbox $passthrough
    else
        _agent_limit codex $launch_options --dangerously-bypass-approvals-and-sandbox $passthrough
    end
end

complete -c codex -l model-gpt-5-5 -d 'Select the gpt-5.5 model preset'
complete -c codex -l model-gpt-5-3-codex -d 'Select the gpt-5.3-codex model preset'
