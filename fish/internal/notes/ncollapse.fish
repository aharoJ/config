# path: ~/.config/fish/internal/notes/ncollapse.fish
# description: Force vague understanding into concrete, testable claims.
# science: Busemeyer & Wang (2015) quantum cognition measurement effects,
#          Holyoak & Simon (1999) judgment restructures representation,
#          Chi et al. (1989) self-explanation effect
# date: 2026-02-24
function ncollapse --description "notes: collapse vague knowledge into specifics"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: ncollapse <concept>"
        echo ""
        echo "Turns 'I kind of get it' into 'here is exactly what I claim.'"
        echo "Vague understanding is the enemy. Specificity is the cure."
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/collapses"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Collapse: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## 5 specific, falsifiable claims about this concept" >>"$file"
        echo "<!-- If you cannot write 5, you do not understand it. -->" >>"$file"
        echo "<!-- Each claim should be something that could be WRONG. -->" >>"$file"
        echo "" >>"$file"
        echo "1. " >>"$file"
        echo "2. " >>"$file"
        echo "3. " >>"$file"
        echo "4. " >>"$file"
        echo "5. " >>"$file"
        echo "" >>"$file"
        echo "## Which claim am I least sure about? Why?" >>"$file"
        echo "" >>"$file"
        echo "## Predict: what happens when [X] changes?" >>"$file"
        echo "<!-- Pick one variable and predict the outcome -->" >>"$file"
        echo "" >>"$file"
        echo "## The boundary: where does this concept stop working?" >>"$file"
        echo "" >>"$file"
        echo "## After checking: which claims were wrong?" >>"$file"
        echo "" >>"$file"
        echo "## Updated model" >>"$file"
        echo "" >>"$file"
    end

    echo "=== KNOWLEDGE COLLAPSE ==="
    echo ""
    echo "You think you understand '$argv'. Prove it."
    echo ""
    echo "Write 5 specific, falsifiable claims."
    echo "If a claim CANNOT be wrong, it is too vague."
    echo "If you cannot write 5, you do not understand it yet."
    echo ""

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
