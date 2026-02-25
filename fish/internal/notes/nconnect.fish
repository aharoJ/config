# path: ~/.config/fish/internal/notes/nconnect.fish
# description: Find potential connections between a note and the rest of your system.
# science: Luhmann Zettelkasten (organic growth through connections), elaborative encoding
# date: 2026-02-24
function nconnect --description "notes: find connections"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nconnect <file-or-search-term>"
        echo "Finds notes that share keywords with the given note."
        return 1
    end

    set -l term (string join ' ' $argv)
    set -l target ""

    # Direct path inside NOTES_DIR
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

    set -l target_rel (string replace "$NOTES_DIR/" "" -- "$target")

    echo "=== Connections for: "(basename "$target")" ==="
    echo ""

    set -l keywords (
        cat "$target" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cs '[:alnum:]' '\n' \
        | sort -u \
        | grep -vE '^(the|and|for|that|this|with|from|are|was|were|have|has|been|will|can|not|but|its|you|your|our|they|them|what|when|how|why|who|which|also|just|more|some|into|over|only|very|than|then|there|here|make|made|most|much|many|such|like|use|using|used|get|got|one|two|three|four|five|about|because|while|where|each|any|all|both|does|did|doing|done|date|created|note|notes|learning|todo|file|markdown)$' \
        | grep -E '.{4,}' \
        | head -20
    )

    if test (count $keywords) -eq 0
        echo "  No keywords extracted (note may be too short)."
        return 0
    end

    set -l found_count 0
    set -l seen_files

    for keyword in $keywords
        set -l matches (
            cd "$NOTES_DIR"; and rg -l -i \
                --glob '!.git/**' --glob '!secret/**' --glob '!templates/**' --glob '*.md' \
                -- "$keyword" 2>/dev/null
        )

        for m in $matches
            # Exclude by full relative path (not basename) to avoid false exclusions
            if test "$m" = "$target_rel"
                continue
            end

            if not contains -- "$m" $seen_files; and test $found_count -lt 15
                echo "  '$keyword' also in: $m"
                set seen_files $seen_files "$m"
                set found_count (math $found_count + 1)
            end
        end
    end

    if test $found_count -eq 0
        echo "  No connections found. This note is isolated."
        echo "  Consider: What existing knowledge does this relate to?"
    else
        echo ""
        echo "Found $found_count potential connections."
        echo "Add links in your note with: See also: [[related-note]]"
    end
end
