# path: ~/.config/fish/internal/notes/encode/nstruggle.fish
# description: Productive failure. Attempt a problem BEFORE any instruction or lookup.
#              Generate 2-3 solution attempts, document where each breaks, then learn
#              the real answer. Failed attempts create mental "hooks" for instruction
#              to attach to — the struggle is the mechanism, not the obstacle.
# science: Kapur (2008) productive failure improves conceptual understanding,
#          Sinha & Kapur (2021) meta-analysis g=0.36-0.87 depending on domain,
#          Schwartz & Bransford (1998) "preparation for future learning" effect
# patched: 2026-02-26
#   - fix: {$time_stamp} brace-delimited (Claude audit)
#   - fix: uses __notes_slug for safe filenames (ChatGPT audit)
# date: 2026-02-26
function nstruggle --description "notes: productive failure (attempt before instruction)"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nstruggle <problem-or-topic>"
        echo ""
        echo "RULE: Do NOT look anything up yet."
        echo "Attempt first. Fail first. Then learn."
        return 1
    end

    set -l slug (__notes_slug $argv)
    set -l day (date +%Y-%m-%d)
    set -l time_stamp (date +%H:%M)
    set -l dir "$NOTES_DIR/learning/struggle"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Struggle: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day at {$time_stamp}_" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## The problem / question" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## Attempt 1" >>"$file"
        echo "<!-- Your first approach. Even if it's wrong, write it fully. -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### Where does attempt 1 break?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## Attempt 2" >>"$file"
        echo "<!-- Try a different angle. What if the opposite were true? -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### Where does attempt 2 break?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## Attempt 3 (optional)" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## NOW look it up — the real answer" >>"$file"
        echo "<!-- Only fill this in AFTER you've exhausted your attempts. -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## What did my failed attempts teach me?" >>"$file"
        echo "<!-- The gap between your attempts and reality IS the learning. -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## Which attempt was closest? Why?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
    end

    echo "=== PRODUCTIVE FAILURE ==="
    echo ""
    echo "  Topic: $argv"
    echo ""
    echo "  RULE: Do NOT look anything up."
    echo ""
    echo "  1. Read the problem."
    echo "  2. Write your best attempt at a solution."
    echo "  3. Identify exactly where it breaks."
    echo "  4. Try again from a different angle."
    echo "  5. THEN — and only then — look up the real answer."
    echo ""
    echo "  Your failed attempts prime your brain to encode the correct answer."
    echo ""

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
