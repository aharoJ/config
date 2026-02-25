# path: ~/.config/fish/internal/notes/ncornell.fish
# description: Cornell-style note with cue column and summary. Forces revision.
# science: Frontiers in Psychology (2025) Cornell method + lasting learning,
#          Shi et al. (2022) structured notes reduce cognitive load
# date: 2026-02-24
function ncornell --description "notes: Cornell-style structured note"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: ncornell <topic>"
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/cornell"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Notes (main content)" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Cues (add AFTER writing notes -- retrieval triggers)" >>"$file"
        echo "<!-- Cover the notes section. Can you reconstruct from these cues alone? -->" >>"$file"
        echo "" >>"$file"
        echo "- " >>"$file"
        echo "- " >>"$file"
        echo "- " >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Summary (write from memory, max 3 sentences)" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Revision pass (fill in 24h later)" >>"$file"
        echo "" >>"$file"
        echo "Revised: [ ]" >>"$file"
        echo "What I missed from memory: " >>"$file"
        echo "New connections: " >>"$file"
        echo "" >>"$file"
    end

    echo "=== CORNELL METHOD ==="
    echo ""
    echo "Phase 1: Write notes in the main section."
    echo "Phase 2: CLOSE the notes. Write cue words from memory."
    echo "Phase 3: Write a 3-sentence summary from memory."
    echo "Phase 4: Come back tomorrow and fill in Revision pass."
    echo ""

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
