# path: ~/.config/fish/internal/notes/nstruggle.fish
# description: Productive failure -- attempt a problem before learning the solution.
# science: Kapur (2008) productive failure, Sinha & Kapur (2021) meta-analysis,
#          Schwartz & Bransford (1998) preparation for future learning
# date: 2026-02-24
function nstruggle --description "notes: productive failure exercise"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nstruggle <concept-you-have-NOT-learned-yet>"
        echo ""
        echo "The point is to FAIL first, then learn."
        echo "The struggle creates mental hooks for the instruction to attach to."
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/struggles"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Productive Failure: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## The problem (what I am trying to solve/understand)" >>"$file"
        echo "" >>"$file"
        echo "## My attempts (BEFORE any instruction/reading)" >>"$file"
        echo "" >>"$file"
        echo "### Attempt 1" >>"$file"
        echo "" >>"$file"
        echo "### Attempt 2" >>"$file"
        echo "" >>"$file"
        echo "### Attempt 3" >>"$file"
        echo "" >>"$file"
        echo "## What I assumed / what prior knowledge I used" >>"$file"
        echo "" >>"$file"
        echo "## Where each attempt breaks down" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## NOW read/learn the actual solution" >>"$file"
        echo "" >>"$file"
        echo "## The canonical approach" >>"$file"
        echo "" >>"$file"
        echo "## What my failed attempts taught me that direct instruction would not have" >>"$file"
        echo "" >>"$file"
        echo "## The gap between my intuition and reality" >>"$file"
        echo "" >>"$file"
    end

    echo "=== PRODUCTIVE FAILURE ==="
    echo ""
    echo "RULES:"
    echo "  1. You WILL fail. That is the point."
    echo "  2. Generate as many solution attempts as possible."
    echo "  3. DO NOT look up the answer until you have at least 2-3 attempts."
    echo "  4. More failed attempts = better learning from the real answer."
    echo ""

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
