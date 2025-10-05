function trash-pick --description 'Pick item(s) from Trash with fzf to restore/delete'
    if not type -q fzf; or not type -q trash-list; or not type -q trash-restore
        echo "Needs fzf + trash-cli"; return 1
    end

    set -l list (trash-list)
    test -z "$list"; and echo "Trash is empty."; and return 0

    # Choose one or more entries; lines look like: "YYYY-MM-DD HH:MM:SS /path"
    set -l chosen (printf "%s\n" $list | fzf --multi --prompt="Trash > " \
        --header="Enter=restore • Ctrl-D=delete • Ctrl-E=empty • Ctrl-O=open Trash folder" \
        --bind 'ctrl-d:execute-silent(echo {+} | sed -E "s/^[0-9-]{10} [0-9:]{8} //" | xargs -0 -I{} trash-rm -- "{}")' \
        --bind 'ctrl-e:execute(trash-empty)' \
        --bind 'ctrl-o:execute(open ~/.Trash || xdg-open ~/.local/share/Trash/files)')

    test -z "$chosen"; and return 0

    # Restore selected paths (strip date/time)
    for line in $chosen
        set -l path (string replace -r '^[0-9-]{10}\s+[0-9:]{8}\s+' '' -- $line)
        trash-restore -- "$path"
    end
end

