# path: ~/.config/fish/internal/notes/nl.fish
# description: Open or create a learning note.
# date: 2026-02-24
function nl --description "notes: learning note"
    if test (count $argv) -eq 0
        echo "Usage: nl <topic> [note-name]"
        return 1
    end

    set -l topic $argv[1]
    set -l name
    if test (count $argv) -ge 2
        set name $argv[2]
    else
        set name "notes"
    end
    set -l dir "$NOTES_DIR/learning/$topic"
    set -l file "$dir/$name.md"

    mkdir -p "$dir"
    if not test -f "$file"
        echo "# $topic / $name" >"$file"
        echo "" >>"$file"
        echo "_Created: "(date '+%Y-%m-%d')"_" >>"$file"
        echo "" >>"$file"
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
