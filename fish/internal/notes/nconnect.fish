# path: ~/.config/fish/internal/notes/nconnect.fish
# description: Find potential connections between a note and the rest of your system.
# science: Luhmann Zettelkasten (organic growth through connections), elaborative encoding
# date: 2026-02-24
function nconnect --description "notes: find connections"
    if test (count $argv) -eq 0
        echo "Usage: nconnect <file-or-search-term>"
        echo "Finds notes that share keywords with the given note."
        return 1
    end

    set -l term (string join ' ' $argv)
    set -l target

    if test -f "$NOTES_DIR/$term"
        set target "$NOTES_DIR/$term"
    else
        set target (cd "$NOTES_DIR"; and find . -name "*$term*" -path '*.md' -not -path '*/.git/*' | head -1)
        if test -n "$target"
            set target "$NOTES_DIR/"(string replace './' '' "$target")
        end
    end

    if test -z "$target"; or not test -f "$target"
        echo "No note found matching: $term"
        return 1
    end

    echo "=== Connections for: "(basename $target)" ==="
    echo ""

    # Extract significant words (skip common words, get unique terms)
    set -l keywords (cat "$target" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cs '[:alnum:]' '\n' \
        | sort -u \
        | grep -vE '^(the|and|for|that|this|with|from|are|was|were|have|has|been|will|can|not|but|its|you|your|all|one|two|our|they|them|what|when|how|why|who|which|also|just|more|some|into|over|only|very|than)$' \
        | grep -E '.{4,}' \
        | head -20)

    set -l found 0
    set -l seen_files

    for keyword in $keywords
        set -l matches (cd "$NOTES_DIR"; and rg -l -i --glob '!.git/**' --glob '!secret/**' -- "$keyword" 2>/dev/null \
            | grep -v (basename "$target"))
        for match in $matches
            if not contains -- "$match" $seen_files; and test $found -lt 15
                echo "  '$keyword' also in: $match"
                set seen_files $seen_files "$match"
                set found (math $found + 1)
            end
        end
    end

    if test $found -eq 0
        echo "  No connections found. This note is isolated."
        echo "  Consider: What existing knowledge does this relate to?"
    else
        echo ""
        echo "Found $found potential connections."
        echo "Add links in your note with: See also: [[related-note]]"
    end
end
