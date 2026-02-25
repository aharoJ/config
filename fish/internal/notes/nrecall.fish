# path: ~/.config/fish/internal/notes/nrecall.fish
# description: Retrieval practice for a specific topic. Recall first, then check notes.
# science: Roediger & Karpicke (2006) testing effect, generation effect (Slamecka & Graf 1978)
# date: 2026-02-24
function nrecall --description "notes: retrieval practice (recall first)"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nrecall <topic>"
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/recall"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Recall: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## Write what I remember (NO LOOKING)" >>"$file"
        echo "" >>"$file"
        echo "## 3 questions I should be able to answer" >>"$file"
        echo "" >>"$file"
        echo "1. " >>"$file"
        echo "2. " >>"$file"
        echo "3. " >>"$file"
        echo "" >>"$file"
        echo "## After checking: what was wrong or missing?" >>"$file"
        echo "" >>"$file"
        echo "## Confidence: [low / medium / high]" >>"$file"
        echo "" >>"$file"
        echo "## Next review: [+1d / +3d / +7d / +14d / +30d]" >>"$file"
        echo "" >>"$file"
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
