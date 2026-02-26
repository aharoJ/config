# path: ~/.config/fish/internal/notes/ndiagram.fish
# description: Create a note with explicit visual/diagram section for dual coding.
# science: Paivio (1971) dual coding theory, Mayer (2001) multimedia learning
# date: 2026-02-24
function ndiagram --description "notes: dual-coded learning note"
    if test (count $argv) -eq 0
        echo "Usage: ndiagram <concept>"
        echo "Creates a note that forces both verbal AND visual encoding."
        return 1
    end
    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/diagrams"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"
    if not test -f "$file"
        echo "# Dual Code: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## Verbal: Explain it in words" >>"$file"
        echo "" >>"$file"
        echo "## Visual: Draw it (ASCII, mermaid, or describe the diagram)" >>"$file"
        echo "" >>"$file"
        echo '```' >>"$file"
        echo "[ Draw the concept here as ASCII art, a flowchart, or describe what the diagram looks like ]" >>"$file"
        echo '```' >>"$file"
        echo "" >>"$file"
        echo "## How the visual and verbal connect" >>"$file"
        echo "" >>"$file"
        echo "## What does the diagram reveal that words alone don't?" >>"$file"
        echo "" >>"$file"
    end
    cd "$NOTES_DIR"; and $EDITOR "$file"
end
