function __kimi_yolo_args
    set -l cleaned
    set -l skip_next 0

    for arg in $argv
        if test $skip_next -eq 1
            set skip_next 0
            continue
        end

        switch $arg
            case --yolo --yes --dangerously-allow-all -y
                continue
            case '--yolo=*' '--yes=*' '--dangerously-allow-all=*'
                continue
            case --config --config-file
                set skip_next 1
                continue
            case '--config=*' '--config-file=*'
                continue
            case '*'
                set -a cleaned $arg
        end
    end

    if test (count $cleaned) -gt 0
        printf '%s\n' $cleaned
    end
end

function kimi --wraps kimi --description "Kimi CLI in YOLO mode"
    set -l cleaned (__kimi_yolo_args $argv)
    command kimi --yolo $cleaned
end
