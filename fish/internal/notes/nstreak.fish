# path: ~/.config/fish/internal/notes/nstreak.fish
# description: Visual streak tracker (month view).
# science: Behavioral consistency research, habit formation (Clear 2018), daily practice culture
# date: 2026-02-24
function nstreak --description "notes: visual streak tracker"
    __notes_require; or return 1

    set -l year (date +%Y)
    set -l month (date +%m)
    set -l today_num (date +%d | string replace -r '^0' '')

    echo "=== $year-$month STREAK ==="
    echo ""

    set -l max_streak 0
    set -l current_streak 0

    for d in (seq 1 $today_num)
        set -l dd (printf "%02d" $d)
        set -l file "$NOTES_DIR/journal/$year/$month/$year-$month-$dd.md"

        if test -f "$file"
            printf "X"
            set current_streak (math $current_streak + 1)
            if test $current_streak -gt $max_streak
                set max_streak $current_streak
            end
        else
            printf "."
            set current_streak 0
        end

        if test (math $d % 7) -eq 0
            echo ""
        end
    end

    echo ""
    echo ""
    echo "X = wrote notes   . = missed"
    echo "Current streak: $current_streak day(s)"
    echo "Best streak this month: $max_streak day(s)"

    set -l learn_count (find "$NOTES_DIR/learning" -type f -name "$year-$month-*.md" 2>/dev/null | wc -l | string trim)
    echo "Learning notes this month: $learn_count"
end
