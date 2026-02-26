# path: ~/.config/fish/internal/notes/nq.fish
# description: Quick-append a thought to today's journal (no editor).
# date: 2026-02-24
function nq --description "notes: quick append"
    if test (count $argv) -eq 0
        echo "Usage: nq <your thought here>"
        return 1
    end

    set -l year (date +%Y)
    set -l month (date +%m)
    set -l day (date +%Y-%m-%d)
    set -l time (date +%H:%M)
    set -l dir "$NOTES_DIR/journal/$year/$month"
    set -l file "$dir/$day.md"

    mkdir -p "$dir"
    if not test -f "$file"
        echo "# $day" >"$file"
    end

    echo "" >>"$file"
    echo "**$time** $argv" >>"$file"
    echo "Noted."
end
