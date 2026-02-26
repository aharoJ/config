# path: ~/.config/fish/internal/notes/retrieve/nrecall.fish
# description: Free recall — the purest and hardest form of retrieval practice.
#              Open a blank page. Write everything you know about a topic. NO LOOKING.
#              Then check against your real notes and log what was wrong or missing.
#              Distinct from nleitner (cued recall with Q&A prompts).
# science: Roediger & Karpicke (2006) testing effect — retrieval beats restudy for long-term retention,
#          Slamecka & Graf (1978) generation effect — self-generated info remembered better,
#          Tulving (1967) free recall engages different retrieval processes than cued recall
# patched: 2026-02-26
#   - fix: {$time_stamp} brace-delimited (Claude audit)
#   - fix: uses __notes_slug for safe filenames (ChatGPT audit)
# date: 2026-02-26
function nrecall --description "notes: free recall (blank page → check)"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nrecall <topic>"
        echo ""
        echo "Write everything you know from memory. NO LOOKING."
        echo "Then check against your real notes."
        return 1
    end

    set -l slug (__notes_slug $argv)
    set -l day (date +%Y-%m-%d)
    set -l time_stamp (date +%H:%M)
    set -l dir "$NOTES_DIR/learning/recall"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Recall: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day at {$time_stamp}_" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Write everything you know (NO LOOKING)" >>"$file"
        echo "<!-- This section must be written entirely from memory. -->" >>"$file"
        echo "<!-- The blank page is the point. Fight through the difficulty. -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## NOW check — what was wrong or missing?" >>"$file"
        echo "<!-- Open your real notes and compare. Be honest. -->" >>"$file"
        echo "" >>"$file"
        echo "### Wrong:" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### Missing:" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### Surprising (knew more than expected):" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## Confidence: [low / medium / high]" >>"$file"
        echo "" >>"$file"
    end

    echo "=== FREE RECALL ==="
    echo ""
    echo "  Topic: $argv"
    echo ""
    echo "  RULE: Write FIRST. Check SECOND."
    echo ""
    echo "  1. Write everything you know about this topic."
    echo "  2. Do not open any notes, docs, or search."
    echo "  3. When you're done, check against real sources."
    echo "  4. Log what was wrong, missing, or surprising."
    echo ""

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
