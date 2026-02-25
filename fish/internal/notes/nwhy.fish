# path: ~/.config/fish/internal/notes/nwhy.fish
# description: Elaborative interrogation prompts for deeper encoding.
# science: Pressley et al. (1988), Dunlosky et al. (2013) moderate-to-high utility technique
# date: 2026-02-24
function nwhy --description "notes: elaborative interrogation"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nwhy <concept>"
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/interrogations"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Interrogation: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## Why does this work the way it does?" >>"$file"
        echo "" >>"$file"
        echo "## How is this different from [related concept]?" >>"$file"
        echo "" >>"$file"
        echo "## What would happen if this were NOT true?" >>"$file"
        echo "" >>"$file"
        echo "## Where have I seen this pattern before?" >>"$file"
        echo "" >>"$file"
        echo "## Simplest real-world example" >>"$file"
        echo "" >>"$file"
        echo "## What did I get wrong on my first attempt?" >>"$file"
        echo "" >>"$file"
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
