# path: ~/.config/fish/internal/notes/nerror.fish
# description: Error notebook. Log a mistake, its trigger pattern, and how to detect it next time.
# science: East Asian error notebook tradition, Bjork (1994) desirable difficulties, metacognitive monitoring
# credit: ChatGPT suggestion, enhanced with mini-drill section
# date: 2026-02-24
function nerror --description "notes: error log"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nerror <mistake topic>"
        echo "       nerror list              Show all logged errors"
        return 1
    end

    if test "$argv[1]" = "list"
        set -l dir "$NOTES_DIR/learning/errors"
        if not test -d "$dir"
            echo "No errors logged yet. (That means you are not practicing hard enough.)"
            return 0
        end
        echo "=== ERROR LOG ==="
        for f in $dir/*.md
            if test -f "$f"
                set -l title (head -1 "$f" | sed 's/^# //')
                echo "  "(basename $f .md)": $title"
            end
        end
        return 0
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/errors"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Error: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## What I did / believed" >>"$file"
        echo "" >>"$file"
        echo "## Why it was wrong (the exact point of failure)" >>"$file"
        echo "" >>"$file"
        echo "## Correct rule / model" >>"$file"
        echo "" >>"$file"
        echo "## Trigger pattern (how to spot this mistake next time)" >>"$file"
        echo "" >>"$file"
        echo "<!-- This is the most important section. -->" >>"$file"
        echo "<!-- If you can describe the CONDITIONS that led to the error, -->" >>"$file"
        echo "<!-- you build a detector that fires before you make it again. -->" >>"$file"
        echo "" >>"$file"
        echo "## Mini drill (2 problems that test this exact gap)" >>"$file"
        echo "" >>"$file"
        echo "1. " >>"$file"
        echo "2. " >>"$file"
        echo "" >>"$file"
        echo "## Related errors" >>"$file"
        echo "<!-- Link to other error notes with the same root cause -->" >>"$file"
        echo "" >>"$file"
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
