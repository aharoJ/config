# path: ~/.config/fish/internal/notes/infrastructure/nf.fish
# description: Fuzzy-find notes by filename using fzf with bat preview.
#              Opens the selected file in $EDITOR. Distinct from ns (content search).
# date: 2026-02-26
function nf --description "notes: fuzzy find by filename"
    __notes_require; or return 1

    if not command -q fzf
        echo "Error: fzf is required. Install: brew install fzf"
        return 1
    end

    cd "$NOTES_DIR"; or return 1

    # WHY: find only .md files, exclude .git and secret directories
    # -name '*.md' is correct (not -path which matches directory components)
    set -l preview_cmd "cat {}"
    if command -q bat
        # WHY: bat gives syntax highlighting and line numbers in the preview
        set preview_cmd "bat --color=always --style=plain --line-range=:50 {}"
    end

    set -l chosen (find . -name '*.md' \
        -not -path '*/.git/*' \
        -not -path '*/secret/*' \
        | sed 's|^\./||' \
        | sort \
        | fzf --prompt="Find note > " \
              --preview="$preview_cmd" \
              --preview-window=right:60%:wrap)

    if test -n "$chosen"
        $EDITOR "$chosen"
    end
end
