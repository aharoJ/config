# path: ~/.config/fish/internal/notes/npresleep.fish
# description: Flag notes for pre-sleep review. Triggers expectation-based consolidation.
# science: Wilhelm et al. (2011) expectancy enhances sleep consolidation, Rasch et al. (2007) hippocampal replay
# date: 2026-02-24
function npresleep --description "notes: pre-sleep review queue"
    __notes_require; or return 1

    set -l queue_file "$NOTES_DIR/.presleep-queue"

    if test (count $argv) -eq 0
        if not test -f "$queue_file"; or test -z (cat "$queue_file" 2>/dev/null | string trim)
            echo "Pre-sleep queue is empty."
            echo "Usage: npresleep <file-or-search-term>  (add)"
            echo "       npresleep                        (review)"
            return 0
        end

        echo "=== PRE-SLEEP REVIEW ==="
        echo ""
        echo "Keep it short. Cue-based skim only."
        echo "Tell yourself: 'I will be tested on this tomorrow.'"
        echo ""

        cat "$queue_file" | while read -l item
            if test -f "$item"
                echo "  - "(string replace "$NOTES_DIR/" "" -- "$item")
            end
        end

        echo ""
        read -P "Press Enter to review... "
        cat "$queue_file" | while read -l item
            if test -f "$item"
                $EDITOR "$item"
            end
        end

        echo "" > "$queue_file"
        echo "Queue cleared."
        return 0
    end

    set -l term (string join ' ' $argv)
    set -l target ""

    if test -f "$NOTES_DIR/$term"
        set target "$NOTES_DIR/$term"
    else
        set -l found (cd "$NOTES_DIR"; and find . -iname "*$term*" -name "*.md" \
            -not -path '*/.git/*' -not -path '*/secret/*' | head -1)
        if test -n "$found"
            set target "$NOTES_DIR/"(string replace './' '' -- "$found")
        end
    end

    if test -z "$target"; or not test -f "$target"
        echo "No note found matching: $term"
        return 1
    end

    # Dedup: don't queue the same note twice
    if test -f "$queue_file"
        if rg -Fqx -- "$target" "$queue_file" 2>/dev/null
            echo "Already queued: "(string replace "$NOTES_DIR/" "" -- "$target")
            return 0
        end
    end

    echo "$target" >> "$queue_file"
    echo "Added to pre-sleep queue: "(string replace "$NOTES_DIR/" "" -- "$target")
end
