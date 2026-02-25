# path: ~/.config/fish/internal/notes/nleitner.fish
# description: Leitner box system -- card-level spaced repetition within a drill deck.
# science: Leitner (1972) learning boxes, adaptive spacing at item level
# date: 2026-02-24
function nleitner --description "notes: Leitner box drill (card-level SRS)"
    __notes_require; or return 1

    if test (count $argv) -lt 2
        echo "Usage:"
        echo "  nleitner run <deck>    - drill due cards using Leitner boxes"
        echo "  nleitner status <deck> - show box distribution"
        echo "  nleitner init <deck>   - initialize tracking for existing deck"
        return 1
    end

    set -l cmd $argv[1]
    set -l deck $argv[2]
    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l file "$deck_dir/$deck.md"
    set -l state_file "$deck_dir/.$deck-leitner.state"

    if not test -f "$file"
        echo "Deck '$deck' not found."
        return 1
    end

    # Parse cards
    set -l questions (rg --no-heading '^Q: ' "$file")
    set -l answers (rg --no-heading '^A: ' "$file")
    set -l total (count $questions)

    if test $total -eq 0
        echo "No cards in deck."
        return 0
    end

    set -l day (date +%Y-%m-%d)

    # Init state if needed
    if not test -f "$state_file"
        for i in (seq 1 $total)
            echo "$i 1 $day"
        end > "$state_file"
    end

    switch $cmd
        case status
            echo "=== LEITNER STATUS: $deck ($total cards) ==="
            echo ""
            for box in 1 2 3 4 5
                set -l count (rg -c " $box " "$state_file" 2>/dev/null; or echo 0)
                set -l interval
                switch $box
                    case 1; set interval "every day"
                    case 2; set interval "every 3 days"
                    case 3; set interval "every 7 days"
                    case 4; set interval "every 14 days"
                    case 5; set interval "every 30 days"
                end
                echo "  Box $box ($interval): $count cards"
            end

        case init
            if test -f "$state_file"
                echo "State already exists. Delete $state_file to reinitialize."
                return 1
            end
            for i in (seq 1 $total)
                echo "$i 1 $day"
            end > "$state_file"
            echo "Initialized Leitner tracking for $deck ($total cards, all in Box 1)."

        case run
            # Determine which cards are due based on box intervals
            set -l due_indices

            while read -l idx box last
                set -l interval
                switch $box
                    case 1; set interval 1
                    case 2; set interval 3
                    case 3; set interval 7
                    case 4; set interval 14
                    case 5; set interval 30
                    case '*'; set interval 1
                end

                # Check if due (macOS first, GNU fallback)
                set -l due_date (date -v+{$interval}d -j -f "%Y-%m-%d" "$last" +%Y-%m-%d 2>/dev/null)
                if test -z "$due_date"
                    set due_date (date -d "$last + $interval days" +%Y-%m-%d 2>/dev/null)
                end

                if test -n "$due_date" -a "$due_date" \<= "$day"
                    set due_indices $due_indices $idx
                end
            end < "$state_file"

            if test (count $due_indices) -eq 0
                echo "No cards due today in $deck."
                echo "Run 'nleitner status $deck' to see distribution."
                return 0
            end

            echo "=== LEITNER DRILL: $deck ("(count $due_indices)" due) ==="
            echo ""

            set -l promoted 0
            set -l demoted 0

            for idx in $due_indices
                if test $idx -gt $total
                    continue
                end

                set -l q $questions[$idx]
                set -l a $answers[$idx]

                # Read current box from state
                set -l current_box (rg "^$idx " "$state_file" | head -1 | string replace -r '^\d+ (\d+) .*' '$1')
                if test -z "$current_box"
                    set current_box 1
                end

                echo "[Box $current_box] $q"
                read -P "  (Enter to reveal) " -l _
                echo "  $a"
                read -P "  Correct? [y/n]: " -l result

                set -l new_box
                if test "$result" = "y"
                    set new_box (math "min($current_box + 1, 5)")
                    set promoted (math $promoted + 1)
                else
                    set new_box 1
                    set demoted (math $demoted + 1)
                end

                # Update state file (macOS sed, then GNU fallback)
                sed -i '' "s/^$idx $current_box .*/$idx $new_box $day/" "$state_file" 2>/dev/null
                or sed -i "s/^$idx $current_box .*/$idx $new_box $day/" "$state_file"

                echo "  -> Box $current_box -> Box $new_box"
                echo ""
            end

            echo "=== DONE ==="
            echo "  Promoted: $promoted  Demoted to Box 1: $demoted"

        case '*'
            echo "Unknown command: $cmd"
            return 1
    end
end
