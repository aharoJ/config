# path: ~/.config/fish/internal/notes/nerror_patterns.fish
# description: Search across all error logs for recurring patterns.
# science: East Asian cuoti (error collection) tradition, metacognitive monitoring
# date: 2026-02-24
function nerror_patterns --description "notes: find recurring error patterns"
    __notes_require; or return 1

    set -l dir "$NOTES_DIR/learning/errors"

    if not test -d "$dir"
        echo "No errors logged yet."
        return 0
    end

    set -l error_files $dir/*.md
    if test (count $error_files) -eq 0; or not test -f "$error_files[1]"
        echo "No errors logged yet."
        return 0
    end

    echo "=== RECURRING ERROR PATTERNS ==="
    echo ""

    echo "--- Trigger patterns across all errors ---"
    echo ""
    rg --no-heading --no-line-number -A3 '^## Trigger pattern' $dir/*.md 2>/dev/null \
        | rg -v '^--$' \
        | rg -v '^## Trigger' \
        | rg -v '<!-- ' \
        | string trim \
        | grep -v '^$' \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -10

    echo ""
    echo "--- Error frequency by month ---"
    echo ""
    for f in $dir/*.md
        if test -f "$f"
            basename "$f" .md | string replace -r '-[a-z].*' ''
        end
    end | sort | uniq -c | sort -rn

    echo ""
    echo "--- Total errors logged ---"
    echo ""
    set -l total_errors (count $dir/*.md)
    echo "  $total_errors errors"
    echo ""

    # Check for duplicate trigger patterns (same mistake repeated)
    set -l repeated (
        rg --no-heading --no-line-number -A3 '^## Trigger pattern' $dir/*.md 2>/dev/null \
        | rg -v '^--$' \
        | rg -v '^## Trigger' \
        | rg -v '<!-- ' \
        | string trim \
        | grep -v '^$' \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -1
    )

    if test -n "$repeated"
        set -l count (echo $repeated | string trim | string replace -r ' .*' '')
        if test -n "$count" -a "$count" -gt 1
            echo "  WARNING: You have repeated trigger patterns."
            echo "  If the same mistake keeps appearing, your detector is not working."
            echo "  Make the trigger pattern more specific and actionable."
        end
    end
end
