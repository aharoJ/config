# path: ~/.config/fish/internal/notes/capture/nq.fish
# description: Append a timestamped one-liner to today's journal. No editor opens.
#              For capturing thoughts mid-flow without context-switching.
#              Distinct from note (which opens $EDITOR — higher friction, deeper capture).
# date: 2026-02-26
function nq --description "notes: quick append to journal (no editor)"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nq <thought>"
        echo ""
        echo "Appends a timestamped line to today's journal."
        echo "No editor opens. Back to work in <1 second."
        return 1
    end

    set -l year (date +%Y)
    set -l month (date +%m)
    set -l day (date +%Y-%m-%d)
    set -l weekday (date +%A)
    set -l time_stamp (date +%H:%M)
    set -l dir "$NOTES_DIR/journal/$year/$month"
    set -l file "$dir/$day.md"

    mkdir -p "$dir"

    # WHY: create journal with template if it doesn't exist yet
    # same template as note.fish — both write to the same file
    if not test -f "$file"
        echo "# $day ($weekday)" >"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Log" >>"$file"
        echo "" >>"$file"
    end

    # WHY: append with timestamp — the journal becomes a timestamped log
    set -l entry (string join ' ' $argv)
    echo "- $time_stamp — $entry" >>"$file"

    echo "  [$time_stamp] → $day.md"
end
