# path: ~/.config/fish/internal/notes/np.fish
# description: Open or create a project note.
# date: 2026-02-24
function np --description "notes: project note"
    if test (count $argv) -eq 0
        echo "Usage: np <project-name> [note-name]"
        return 1
    end

    set -l project $argv[1]
    set -l name
    if test (count $argv) -ge 2
        set name $argv[2]
    else
        set name "notes"
    end
    set -l dir "$NOTES_DIR/projects/$project"
    set -l file "$dir/$name.md"

    mkdir -p "$dir"
    if not test -f "$file"
        echo "# $project / $name" >"$file"
        echo "" >>"$file"
        echo "_Created: "(date '+%Y-%m-%d')"_" >>"$file"
        echo "" >>"$file"
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
