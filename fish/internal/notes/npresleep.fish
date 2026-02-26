# path: ~/.config/fish/internal/notes/npresleep.fish
# description: Flag notes for pre-sleep review. Triggers expectation-based consolidation.
# science: Wilhelm et al. (2011) expectancy enhances sleep consolidation, Rasch et al. (2007) hippocampal replay
# date: 2026-02-24
function npresleep --description "notes: pre-sleep review queue"
    set -l queue_file "$NOTES_DIR/.presleep-queue"

    if test (count $argv) -eq 0
        # Show and run the queue
        if not test -f "$queue_file"; or test -z (cat "$queue_file" 2>/dev/null | string trim)
            echo "Pre-sleep queue is empty."
            echo "Usage: npresleep <file-or-search-term>  to add items"
            echo "       npresleep                        to review queue"
            return 0
        end

        echo "=== PRE-SLEEP REVIEW ==="
        echo ""
        echo "Quick review these items, then sleep."
        echo "Your brain will consolidate them overnight."
        echo "Tell yourself: 'I will be tested on this tomorrow.'"
        echo "(This expectation measurably improves consolidation.)"
        echo ""

        cat "$queue_file" | while read -l item
            if test -f "$item"
                echo "  - "(string replace "$NOTES_DIR/" "" "$item")
            end
        end

        echo ""
        read -P "Press Enter to review... "

        cat "$queue_file" | while read -l item
            if test -f "$item"
                $EDITOR "$item"
            end
        end

        # Clear queue after review
        echo "" > "$queue_file"
        echo "Queue cleared. Sleep well. You WILL be tested tomorrow."
        return 0
    end

    # Add to queue
    set -l term (string join ' ' $argv)
    set -l target

    # Check if it is a direct file path
    if test -f "$NOTES_DIR/$term"
        set target "$NOTES_DIR/$term"
    else
        # Search for it
        set target (cd "$NOTES_DIR"; and find . -name "*$term*" -path '*.md' -not -path '*/.git/*' | head -1)
        if test -n "$target"
            set target "$NOTES_DIR/"(string replace './' '' "$target")
        end
    end

    if test -z "$target"
        echo "No note found matching: $term"
        return 1
    end

    echo "$target" >> "$queue_file"
    echo "Added to pre-sleep queue: "(string replace "$NOTES_DIR/" "" "$target")
end
