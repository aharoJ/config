# path: ~/.config/fish/internal/notes/nlinks.fish
# description: Find all notes that reference a topic.
# date: 2026-02-24
function nlinks --description "notes: find cross-references"
    if test (count $argv) -eq 0
        echo "Usage: nlinks <search-term>"
        echo "Finds all notes that link TO or mention a topic."
        return 1
    end
    cd "$NOTES_DIR"
    echo "=== Notes referencing: $argv ==="
    rg --glob '!secret/**' --glob '!.git/**' -l -i -- (string join ' ' $argv)
end
