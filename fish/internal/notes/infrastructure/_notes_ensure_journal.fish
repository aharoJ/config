# path: ~/.config/fish/internal/notes/infrastructure/_notes_ensure_journal.fish
# description: Ensures today's journal file exists with the standard template.
#              Shared by note.fish and nq.fish — single source of truth for the
#              journal template. Returns the file path via stdout.
# fixes: Claude audit — duplicated journal template between note.fish and nq.fish
# patched: 2026-02-26
#   - fix: check mkdir -p success — permission errors would silently cascade
#     into failed writes (Kimi second-pass audit)
# date: 2026-02-26
function _notes_ensure_journal
    set -l year (date +%Y)
    set -l month (date +%m)
    set -l day (date +%Y-%m-%d)
    set -l weekday (date +%A)
    set -l dir "$NOTES_DIR/journal/$year/$month"
    set -l file "$dir/$day.md"

    # WHY: check mkdir success — if permissions deny creation, better to fail
    # here with a clear message than cascade into silent write failures (Kimi audit)
    if not mkdir -p "$dir" 2>/dev/null
        echo "Error: could not create journal directory: $dir" >&2
        return 1
    end

    # WHY: only create template if file doesn't exist — never overwrite
    if not test -f "$file"
        echo "# $day ($weekday)" >"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Log" >>"$file"
        echo "" >>"$file"
    end

    # WHY: return the path so callers can use it
    echo "$file"
end
