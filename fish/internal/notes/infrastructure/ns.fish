# path: ~/.config/fish/internal/notes/infrastructure/ns.fish
# description: Full-text search across all notes using ripgrep. Distinct from nf
#              (filename search). Excludes .git and secret directories.
# patched: 2026-02-26
#   - fix: rg now restricts to *.md files (ChatGPT audit — was searching .state files)
#   - fix: grep fallback uses find pipeline (DeepSeek audit — BSD grep lacks --exclude-dir)
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
        # WHY: --glob '*.md' restricts to markdown files only — prevents matching
        # .state files, queue files, or other internal data (ChatGPT audit)
        rg --glob '!.git/' \
           --glob '!secret/' \
           --glob '*.md' \
           --ignore-case \
           --color=always \
           --heading \
           --line-number \
           -- "$query" "$NOTES_DIR"
    else
        # WHY: find-based pipeline instead of grep --exclude-dir
        # BSD grep (macOS) does not support --exclude-dir (DeepSeek audit)
        find "$NOTES_DIR" -name '*.md' \
            -not -path '*/.git/*' \
            -not -path '*/secret/*' \
            -exec grep -ni --color=always -- "$query" {} +
    end
end
