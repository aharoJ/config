# path: ~/.config/fish/internal/notes/ntimed.fish
# description: Timed retrieval drill. Measures speed of recall, not just accuracy.
# science: Kumon method (fluency = mastery), Anderson (1982) knowledge compilation,
#          Rickard (1997) identical elements model of arithmetic retrieval
# date: 2026-02-24
function ntimed --description "notes: timed retrieval drill"
    __notes_require; or return 1

    if test (count $argv) -lt 1
        echo "Usage: ntimed <deck> [seconds-per-card]"
        echo ""
        echo "Like ndrill, but tracks response time."
        echo "True mastery = correct AND fast (under threshold)."
        return 1
    end

    set -l deck $argv[1]
    set -l threshold 10
    if test (count $argv) -ge 2; and string match -qr '^\d+$' -- $argv[2]
        set threshold $argv[2]
    end

    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l file "$deck_dir/$deck.md"

    if not test -f "$file"
        echo "Deck '$deck' not found."
        return 1
    end

    set -l questions (rg --no-heading '^Q: ' "$file")
    set -l answers (rg --no-heading '^A: ' "$file")
    set -l total (count $questions)

    if test $total -eq 0
        echo "No cards in deck: $deck"
        return 0
    end

    set -l correct 0
    set -l fast 0
    set -l slow 0
    set -l missed 0

    echo "=== TIMED DRILL: $deck ($total cards, ${threshold}s threshold) ==="
    echo "Answer BEFORE revealing. Speed matters."
    echo ""

    for i in (seq 1 $total)
        echo "[$i/$total] $questions[$i]"
        set -l start (date +%s)
        read -P "  Your answer (Enter to reveal): " -l _
        set -l end_time (date +%s)
        set -l elapsed (math "$end_time - $start")
        echo "  $answers[$i]"
        echo "  (${elapsed}s)"

        read -P "  Correct? [y/n]: " -l result
        if test "$result" = "y"
            set correct (math $correct + 1)
            if test $elapsed -le $threshold
                set fast (math $fast + 1)
                echo "  -> MASTERED (correct + fast)"
            else
                set slow (math $slow + 1)
                echo "  -> CORRECT but SLOW (need more reps)"
            end
        else
            set missed (math $missed + 1)
            echo "  -> MISSED"
        end
        echo ""
    end

    echo "=== RESULTS ==="
    echo "  Mastered (correct + fast): $fast/$total"
    echo "  Correct but slow:          $slow/$total"
    echo "  Missed:                    $missed/$total"
    echo ""

    if test $slow -gt 0
        echo "  $slow cards need more repetition for fluency."
        echo "  Correct is not enough. Speed indicates true compilation."
    end
    if test $missed -gt 0
        echo "  $missed cards need re-learning. Review tomorrow."
    end
end
