# path: ~/.config/fish/internal/notes/nreview.fish
# description: Spaced review with active recall prompts. Shows notes from 1, 3, 7, 14, 30 days ago.
# science: Ebbinghaus forgetting curve, Cepeda (2008) optimal intervals, Roediger & Karpicke (2006) testing effect
# date: 2026-02-24
function nreview --description "notes: spaced review (active recall)"
    __notes_require; or return 1

    echo "=== SPACED REVIEW ==="
    echo ""
    echo "RULE: Recall FIRST. Then open to check."
    echo ""

    set -l found 0
    set -l files_to_review

    for days in 1 3 7 14 30
        set -l target (date -v-{$days}d +%Y-%m-%d 2>/dev/null)
        if test -z "$target"
            set target (date -d "$days days ago" +%Y-%m-%d 2>/dev/null)
        end

        if test -n "$target"
            set -l year (echo $target | cut -d'-' -f1)
            set -l month (echo $target | cut -d'-' -f2)
            set -l file "$NOTES_DIR/journal/$year/$month/$target.md"

            if test -f "$file"
                echo "  [$days day(s) ago]  $target"
                set -l headings (rg --no-heading '^##? ' "$file" 2>/dev/null | head -5)
                for h in $headings
                    echo "    $h"
                end
                set files_to_review $files_to_review "$file"
                set found (math $found + 1)
            end
        end
    end

    for days in 1 3 7 14 30
        set -l target (date -v-{$days}d +%Y-%m-%d 2>/dev/null)
        if test -z "$target"
            set target (date -d "$days days ago" +%Y-%m-%d 2>/dev/null)
        end

        if test -n "$target"
            set -l learn_files (find "$NOTES_DIR/learning" -type f -name "$target-*.md" 2>/dev/null)
            for f in $learn_files
                echo "  [$days day(s) ago]  "(string replace "$NOTES_DIR/" "" -- "$f")
                set files_to_review $files_to_review "$f"
                set found (math $found + 1)
            end
        end
    end

    if test $found -eq 0
        echo "  No notes found at review intervals."
        return 0
    end

    echo ""
    echo "--- ACTIVE RECALL PROTOCOL ---"
    echo "1) Close your eyes: what do you remember from each date?"
    echo "2) Write recall: nq \"<what I remember>\""
    echo "3) THEN open notes and check"
    echo "4) For gaps: nerror + add 2 mini drills"
    echo ""

    read -P "Press Enter to open notes for checking... "
    for f in $files_to_review
        $EDITOR "$f"
    end
end
