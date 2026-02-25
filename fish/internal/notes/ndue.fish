# path: ~/.config/fish/internal/notes/ndue.fish
# description: List and open notes whose frontmatter next_review <= today.
#              The single "due queue" that turns your notes from a library into a training system.
# science: SM-2 spaced repetition (Wozniak), Cepeda (2008) adaptive spacing
# requires: frontmatter with `next_review: YYYY-MM-DD` in any .md file
# date: 2026-02-24
function ndue --description "notes: show due items"
    __notes_require; or return 1

    set -l today (date +%Y-%m-%d)

    # Find all files that have a next_review field
    set -l candidates (rg -l --glob '!.git/**' --glob '!secret/**' --glob '*.md' \
        'next_review:' "$NOTES_DIR" 2>/dev/null)

    if test (count $candidates) -eq 0
        echo "No notes have next_review dates set."
        echo ""
        echo "To schedule a note, use: nrate <file>"
        echo "Or add frontmatter manually:"
        echo "  ---"
        echo "  next_review: $today"
        echo "  ---"
        return 0
    end

    # Filter to notes that are due today or overdue
    set -l due_files (
        for f in $candidates
            set -l nr (rg --no-heading --no-line-number --replace '$1' \
                '^next_review:\s*(\d{4}-\d{2}-\d{2})' "$f" | head -1)

            if test -n "$nr"
                if test "$nr" \<= "$today"
                    echo "$f"
                end
            end
        end
    )

    if test (count $due_files) -eq 0
        echo "Nothing due today."
        echo ""
        echo "Scheduled notes: "(count $candidates)
        echo "Upcoming:"
        # Show next few scheduled items so you know what is coming
        for f in $candidates
            set -l nr (rg --no-heading --no-line-number --replace '$1' \
                '^next_review:\s*(\d{4}-\d{2}-\d{2})' "$f" | head -1)
            if test -n "$nr"
                echo "  $nr  "(string replace "$NOTES_DIR/" "" -- "$f")
            end
        end | sort | head -5
        return 0
    end

    echo "=== DUE NOTES (as of $today) ==="
    echo ""
    echo (count $due_files)" note(s) due for review."
    echo ""

    for f in $due_files
        set -l nr (rg --no-heading --no-line-number --replace '$1' \
            '^next_review:\s*(\d{4}-\d{2}-\d{2})' "$f" | head -1)
        set -l relative (string replace "$NOTES_DIR/" "" -- "$f")
        if test "$nr" = "$today"
            echo "  [TODAY]    $relative"
        else
            echo "  [OVERDUE]  $relative  (was due $nr)"
        end
    end

    echo ""
    echo "After reviewing, rate recall with: nrate <file>"
    echo ""

    set -l picked (printf "%s\n" $due_files | sed "s|^$NOTES_DIR/||" | fzf --prompt="Open due note > ")

    if test -n "$picked"
        $EDITOR "$NOTES_DIR/$picked"
        echo ""
        echo "Rate your recall now? Run: nrate $picked"
    end
end
