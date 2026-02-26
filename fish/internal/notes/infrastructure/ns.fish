# path: ~/.config/fish/internal/notes/infrastructure/ns.fish
# description: Full-text search across all notes using ripgrep. Distinct from nf
#              (filename search). Excludes .git and secret directories.
# date: 2026-02-26
function ns --description "notes: full-text search"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: ns <search-term>"
        echo ""
        echo "Searches content of all notes. Use nf to find by filename."
        return 1
    end

    set -l query (string join ' ' $argv)

    if command -q rg
        # WHY: ripgrep is faster than grep and respects .gitignore by default
        # --glob excludes are explicit for clarity even though .gitignore covers .git
        rg --glob '!.git/' \
           --glob '!secret/' \
           --ignore-case \
           --color=always \
           --heading \
           --line-number \
           -- "$query" "$NOTES_DIR"
    else
        # WHY: fallback to grep if ripgrep not installed
        grep -rni \
            --include='*.md' \
            --exclude-dir='.git' \
            --exclude-dir='secret' \
            --color=always \
            -- "$query" "$NOTES_DIR"
    end
end
