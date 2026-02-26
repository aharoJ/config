# path: ~/.config/fish/internal/notes/nf.fish
# description: Fuzzy-find any note. Uses bat for preview if available, falls back to sed.
# credit: ChatGPT improvement (bat fallback, space handling)
# date: 2026-02-24
function nf --description "notes: fuzzy find"
    __notes_require; or return 1

    set -l preview
    if type -q bat
        set preview 'bat --style=numbers,changes --color=always --line-range=:200 "$NOTES_DIR/{}"'
    else
        set preview 'sed -n "1,120p" "$NOTES_DIR/{}"'
    end

    set -l file (
        cd "$NOTES_DIR"; and rg --files \
            --glob '!.git/**' --glob '!secret/**' --glob '*.md' | \
        fzf --preview "$preview" --preview-window=right:60%:wrap
    )

    if test -n "$file"
        cd "$NOTES_DIR"; and $EDITOR "$NOTES_DIR/$file"
    end
end
