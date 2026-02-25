# path: ~/.config/fish/internal/notes/nmorning.fish
# description: Morning recall ritual. Tests what you remember from yesterday.
# science: Sleep consolidation testing (Rasch 2007), retrieval practice as learning event (Roediger 2006)
# date: 2026-02-24
function nmorning --description "notes: morning recall test"
    __notes_require; or return 1

    set -l yesterday (date -v-1d +%Y-%m-%d 2>/dev/null)
    if test -z "$yesterday"
        set yesterday (date -d "1 day ago" +%Y-%m-%d 2>/dev/null)
    end

    set -l year (echo $yesterday | cut -d'-' -f1)
    set -l month (echo $yesterday | cut -d'-' -f2)
    set -l yfile "$NOTES_DIR/journal/$year/$month/$yesterday.md"

    set -l today (date +%Y-%m-%d)
    set -l tyear (date +%Y)
    set -l tmonth (date +%m)
    set -l tdir "$NOTES_DIR/journal/$tyear/$tmonth"
    set -l tfile "$tdir/$today.md"
    mkdir -p "$tdir"

    if not test -f "$tfile"
        if test -f "$NOTES_DIR/templates/daily.md"
            sed "s/{{DATE}}/$today/g" "$NOTES_DIR/templates/daily.md" >"$tfile"
        else
            echo "# $today" >"$tfile"
            echo "" >>"$tfile"
        end
    end

    echo "=== MORNING RECALL ==="
    echo ""
    echo "Before looking at anything:"
    echo "1) What did I learn yesterday?"
    echo "2) What was the most important thing I worked on?"
    echo "3) What connections do I remember?"
    echo ""

    read -P "Quick recall (Enter = open editor): " -l quick
    if test -n "$quick"
        # Avoid duplicate header if rerun
        if not rg -q '^## Morning Recall$' "$tfile"
            echo "" >>"$tfile"
            echo "## Morning Recall" >>"$tfile"
            echo "" >>"$tfile"
        end
        echo "$quick" >>"$tfile"
        echo "" >>"$tfile"
        echo "Recall logged to: "(string replace "$NOTES_DIR/" "" -- "$tfile")
    else
        $EDITOR "$tfile"
    end

    echo ""
    if test -f "$yfile"
        echo "Now check yesterday's journal to see what you missed:"
        read -P "Press Enter to open yesterday... "
        $EDITOR "$yfile"
    else
        echo "No journal entry found for yesterday: $yesterday"
    end

    set -l yesterday_learning (find "$NOTES_DIR/learning" -type f -name "$yesterday-*.md" 2>/dev/null)
    if test (count $yesterday_learning) -gt 0
        echo ""
        echo "You also have these learning notes from yesterday:"
        for f in $yesterday_learning
            echo "  - "(basename "$f")
        end
        read -P "Press Enter to review... "
        for f in $yesterday_learning
            $EDITOR "$f"
        end
    end
end
