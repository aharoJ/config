# path: ~/.config/fish/internal/notes/nreview.fish
# description: Spaced review with active recall prompts. Shows notes from 1, 3, 7, 14, 30 days ago.
# science: Ebbinghaus forgetting curve, Cepeda (2008) optimal intervals, Roediger & Karpicke (2006) testing effect
# date: 2026-02-24
function nreview --description "notes: spaced review (active recall)"
    echo "=== SPACED REVIEW ==="
    echo ""
    echo "RULE: Try to RECALL each day's content BEFORE opening the file."
    echo "      The struggle IS the learning. Failed recall still helps."
    echo ""
    set -l found 0
    set -l files_to_review

    for days in 1 3 7 14 30
        # macOS date syntax
        set -l target (date -v-{$days}d +%Y-%m-%d 2>/dev/null)
        # fallback to GNU date
        if test -z "$target"
            set target (date -d "$days days ago" +%Y-%m-%d 2>/dev/null)
        end

        if test -n "$target"
            set -l year (echo $target | cut -d'-' -f1)
            set -l month (echo $target | cut -d'-' -f2)
            set -l file "$NOTES_DIR/journal/$year/$month/$target.md"

            if test -f "$file"
                echo "  [$days day(s) ago]  $target"
                # Show only the headings as recall cues, not the content
                set -l headings (grep '^##\? ' "$file" 2>/dev/null | head -5)
                for h in $headings
                    echo "    $h"
                end
                set files_to_review $files_to_review "$file"
                set found (math $found + 1)
            end
        end
    end

    # Also check learning/ TILs and feynman notes at these intervals
    for days in 1 3 7 14 30
        set -l target (date -v-{$days}d +%Y-%m-%d 2>/dev/null)
        if test -z "$target"
            set target (date -d "$days days ago" +%Y-%m-%d 2>/dev/null)
        end
        if test -n "$target"
            set -l til_files (find "$NOTES_DIR/learning" -name "$target-*.md" 2>/dev/null)
            for f in $til_files
                echo "  [$days day(s) ago]  "(basename $f)
                set files_to_review $files_to_review "$f"
                set found (math $found + 1)
            end
        end
    end

    if test $found -eq 0
        echo "  No notes found at review intervals."
    end

    echo ""
    echo "--- ACTIVE RECALL PROTOCOL ---"
    echo "1. Close your eyes. What do you remember from each date above?"
    echo "2. Write down everything you can recall (use: nq <your recall>)"
    echo "3. THEN open each note and check what you missed"
    echo "4. For each gap, ask: WHY did I forget this? HOW does it connect?"
    echo ""

    if test (count $files_to_review) -gt 0
        read -P "Press Enter to open notes for checking (recall first!)... "
        for f in $files_to_review
            $EDITOR "$f"
        end
    end
end
