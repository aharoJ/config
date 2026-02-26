# path: ~/.config/fish/internal/notes/nfeynman.fish
# description: Feynman technique: explain a concept like you are 12.
# date: 2026-02-24
function nfeynman --description "notes: feynman explanation"
    if test (count $argv) -eq 0
        echo "Usage: nfeynman <concept>"
        return 1
    end
    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/feynman"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"
    echo "# Feynman: $argv" >"$file"
    echo "" >>"$file"
    echo "## Explain it like I am 12" >>"$file"
    echo "" >>"$file"
    echo "## Where did I get stuck?" >>"$file"
    echo "" >>"$file"
    echo "## Second attempt (after filling gaps)" >>"$file"
    echo "" >>"$file"
    cd "$NOTES_DIR"; and $EDITOR "$file"
end
