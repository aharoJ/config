# path: ~/.config/fish/internal/notes/til.fish
# description: Today I Learned: atomic Zettelkasten-style learning note.
# date: 2026-02-24
function til --description "notes: today I learned"
    if test (count $argv) -eq 0
        echo "Usage: til <topic-slug>"
        return 1
    end
    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/til"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"
    if not test -f "$file"
        echo "# TIL: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## In my own words" >>"$file"
        echo "" >>"$file"
        echo "## Why it matters" >>"$file"
        echo "" >>"$file"
        echo "## Related" >>"$file"
        echo "<!-- Link to other TILs or notes -->" >>"$file"
        echo "" >>"$file"
    end
    cd "$NOTES_DIR"; and $EDITOR "$file"
end
