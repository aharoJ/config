# fish/functions/yazi.fish
function yazi --wraps yazi --description "Yazi with smart cd"
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    command yazi $argv --cwd-file="$tmp"
    if test -f "$tmp"
        set -l cwd (cat "$tmp")
        if test -n "$cwd" -a "$cwd" != "$PWD"
            cd "$cwd"
        end
        rm -f "$tmp"
    end
end
