# path: ~/.config/fish/internal/notes/capture/note.fish
# description: Open today's journal entry in $EDITOR. Creates the file from a template
#              if it doesn't exist yet. The journal is the primary daily capture surface.
# date: 2026-02-26
function note --description "notes: open today's journal"
    __notes_require; or return 1

    set -l year (date +%Y)
    set -l month (date +%m)
    set -l day (date +%Y-%m-%d)
    set -l weekday (date +%A)
    set -l dir "$NOTES_DIR/journal/$year/$month"
    set -l file "$dir/$day.md"

    mkdir -p "$dir"

    # WHY: only create template if file doesn't exist — never overwrite
    if not test -f "$file"
        echo "# $day ($weekday)" >"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Log" >>"$file"
        echo "" >>"$file"
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
