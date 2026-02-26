# path: ~/.config/fish/internal/notes/nstats.fish
# description: Monthly consistency tracker with streak detection.
# date: 2026-02-24
function nstats --description "notes: monthly stats"
    set -l year (date +%Y)
    set -l month (date +%m)
    set -l dir "$NOTES_DIR/journal/$year/$month"

    if not test -d "$dir"
        echo "No notes this month yet. Start with: note"
        return 0
    end

    set -l count (find "$dir" -maxdepth 1 -name '*.md' | wc -l | string trim)
    set -l today (date +%d | string replace -r '^0' '')

    echo "=== $year-$month Notes Stats ==="
    echo "Notes written: $count / $today days so far"
    echo ""

    set -l missing 0
    for d in (seq 1 $today)
        set -l dd (printf "%02d" $d)
        set -l file "$dir/$year-$month-$dd.md"
        if not test -f "$file"
            echo "  Missing: $year-$month-$dd"
            set missing (math $missing + 1)
        end
    end

    if test $missing -eq 0
        echo "  Perfect streak this month!"
    end

    echo ""

    # Total notes across all time
    set -l total (find "$NOTES_DIR" -name '*.md' -not -path '*/.git/*' -not -path '*/secret/*' | wc -l | string trim)
    echo "Total notes in system: $total"
end
