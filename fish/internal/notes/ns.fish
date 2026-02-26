# path: ~/.config/fish/internal/notes/ns.fish
# description: Search note contents (requires ripgrep).
# date: 2026-02-24
function ns --description "notes: search contents"
    if test (count $argv) -eq 0
        echo "Usage: ns <search-term>"
        return 1
    end
    cd "$NOTES_DIR"; and rg --glob '!secret/**' --glob '!.git/**' -i -- $argv
end
