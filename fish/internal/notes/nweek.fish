# path: ~/.config/fish/internal/notes/nweek.fish
# description: Weekly review with interleaving and connection prompts.
# science: Spaced retrieval, interleaving (Rohrer 2012), elaborative interrogation
# date: 2026-02-24
function nweek --description "notes: weekly review"
    set -l week (date +%Y-W%V)
    set -l dir "$NOTES_DIR/journal/reviews"
    set -l file "$dir/$week.md"
    mkdir -p "$dir"
    if not test -f "$file"
        echo "# Week Review: $week" >"$file"
        echo "" >>"$file"
        echo "## What do I remember from this week? (write BEFORE reviewing)" >>"$file"
        echo "" >>"$file"
        echo "## After reviewing: what did I miss?" >>"$file"
        echo "" >>"$file"
        echo "## Key connections across topics" >>"$file"
        echo "" >>"$file"
        echo "<!-- This is the most important section. -->" >>"$file"
        echo "<!-- Real learning = connecting ideas across domains. -->" >>"$file"
        echo "<!-- How does what you learned in [topic A] relate to [topic B]? -->" >>"$file"
        echo "" >>"$file"
        echo "## Interleaving check: pick 3 random old notes (run: ninterleave 3)" >>"$file"
        echo "" >>"$file"
        echo "What surprised me from the random notes?" >>"$file"
        echo "" >>"$file"
        echo "## What needs deeper study next week?" >>"$file"
        echo "" >>"$file"
        echo "## Difficulty rating: What felt hardest this week?" >>"$file"
        echo "" >>"$file"
        echo "<!-- If nothing felt hard, you are not learning. Seek desirable difficulties. -->" >>"$file"
        echo "" >>"$file"
    end
    cd "$NOTES_DIR"; and $EDITOR "$file"
end
