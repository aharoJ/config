# path: ~/.config/fish/internal/notes/nmorning.fish
# description: Morning recall ritual. Tests what you remember from yesterday.
# science: Sleep consolidation testing (Rasch 2007), retrieval practice as learning event (Roediger 2006)
# date: 2026-02-24
function nmorning --description "notes: morning recall test"
    set -l yesterday
    set yesterday (date -v-1d +%Y-%m-%d 2>/dev/null)
    if test -z "$yesterday"
        set yesterday (date -d "1 day ago" +%Y-%m-%d 2>/dev/null)
    end

    set -l year (echo $yesterday | cut -d'-' -f1)
    set -l month (echo $yesterday | cut -d'-' -f2)
    set -l file "$NOTES_DIR/journal/$year/$month/$yesterday.md"

    echo "=== MORNING RECALL ==="
    echo ""
    echo "Before looking at yesterday's notes:"
    echo ""
    echo "1. What did you learn yesterday?"
    echo "2. What was the most important thing you worked on?"
    echo "3. What connections did you notice?"
    echo ""
    echo "Write your recall now (this goes into today's journal):"
    echo ""

    # Create today's journal if needed
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

    read -P "Quick recall (or press Enter to type in editor): " -l quick_recall
    if test -n "$quick_recall"
        echo "" >>"$tfile"
        echo "## Morning Recall" >>"$tfile"
        echo "" >>"$tfile"
        echo "$quick_recall" >>"$tfile"
        echo "" >>"$tfile"
        echo "Recall logged."
    end

    echo ""
    if test -f "$file"
        echo "Now check yesterday's notes to see what you missed:"
        read -P "Press Enter to open yesterday's journal... "
        $EDITOR "$file"
    else
        echo "No journal entry found for yesterday."
    end

    # Also check TILs and learning notes from yesterday
    set -l yesterday_learning (find "$NOTES_DIR/learning" -name "$yesterday-*.md" 2>/dev/null)
    if test (count $yesterday_learning) -gt 0
        echo ""
        echo "You also have these learning notes from yesterday:"
        for f in $yesterday_learning
            echo "  - "(basename $f)
        end
        read -P "Press Enter to review... "
        for f in $yesterday_learning
            $EDITOR "$f"
        end
    end
end
