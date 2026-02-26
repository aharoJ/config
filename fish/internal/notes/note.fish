# path: ~/.config/fish/internal/notes/note.fish
# description: Open today's journal entry (creates from template if needed).
# date: 2026-02-24
function note --description "notes: open today's journal"
    set -l year (date +%Y)
    set -l month (date +%m)
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/journal/$year/$month"
    set -l file "$dir/$day.md"

    mkdir -p "$dir"

    if not test -f "$file"
        if test -f "$NOTES_DIR/templates/daily.md"
            sed "s/{{DATE}}/$day/g" "$NOTES_DIR/templates/daily.md" >"$file"
        else
            echo "# $day" >"$file"
            echo "" >>"$file"
        end
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
