# path: ~/.config/fish/internal/notes/integrate/ninterleave.fish
# description: Interleaved practice. Selects N notes from DIFFERENT topics
#              and opens them in sequence. The forced context-switching between unrelated
#              topics creates discriminative contrast — you have to figure out WHICH
#              approach applies, not just execute one approach repeatedly.
# science: Taylor & Rohrer (2010) interleaving improved math performance d≈0.5-1.21,
#          Kornell & Bjork (2008) interleaving improves inductive learning,
#          Bjork (1994) desirable difficulties — interleaving is harder but better
# patched: 2026-02-26
#   - fix: enforce distinct topic buckets — one note per subdirectory max (ChatGPT audit)
#   - fix: include calibrate/ directory in candidate pool (Claude audit)
#   - fix: add -type f to all find commands — directories named *.md would
#     match and break preview/editor (Kimi second-pass audit)
# date: 2026-02-26
function ninterleave --description "notes: interleaved mixed-topic review"
    __notes_require; or return 1

    set -l count 3
    if test (count $argv) -ge 1
        if string match -qr '^[0-9]+$' "$argv[1]"
            set count $argv[1]
        end
    end

    # WHY: collect notes grouped by subdirectory (= topic bucket)
    # each subdirectory represents a distinct cognitive domain
    # WHY: include calibrate/ — was missing from original (Claude audit)
    set -l bucket_dirs
    for subdir in why struggle recall errors drills calibrate
        set -l dir "$NOTES_DIR/learning/$subdir"
        if test -d "$dir"
            # WHY: -type f ensures we only match real files, not directories
            # named *.md (Kimi audit)
            set -l has_notes (find "$dir" -type f -name '*.md' 2>/dev/null | head -1)
            if test -n "$has_notes"
                set bucket_dirs $bucket_dirs "$dir"
            end
        end
    end

    if test (count $bucket_dirs) -lt $count
        echo "Not enough topic buckets for interleaving."
        echo "Found "(count $bucket_dirs)" topic(s) with notes, need at least $count."
        echo ""
        echo "Available buckets:"
        for d in $bucket_dirs
            echo "  "(basename "$d")" ("(find "$d" -type f -name '*.md' | wc -l | string trim)" notes)"
        end
        echo ""
        echo "Keep studying across different topics. Interleaving works best"
        echo "with notes spread across multiple categories."
        return 1
    end

    # WHY: shuffle the bucket directories, then pick one random note from each
    # this GUARANTEES notes come from different topics (ChatGPT audit:
    # "the code just pools all candidates and picks random ones — can choose
    # multiple files from the same subdirectory/topic family")
    # WHY: check awk availability — it's used for random shuffling (Sweep audit)
    if not command -q awk
        echo "Error: awk is required for random selection."
        return 1
    end
    set -l shuffled_buckets (printf '%s\n' $bucket_dirs | awk 'BEGIN{srand()}{print rand()"\t"$0}' | sort -n | cut -f2- | head -n $count)

    set -l selected
    for bucket in $shuffled_buckets
        # WHY: pick one random note from this bucket
        # WHY: -type f for safety (Kimi audit)
        set -l pick (find "$bucket" -type f -name '*.md' 2>/dev/null | awk 'BEGIN{srand()}{print rand()"\t"$0}' | sort -n | cut -f2- | head -1)
        if test -n "$pick"
            set selected $selected "$pick"
        end
    end

    set -l actual_count (count $selected)
    if test $actual_count -eq 0
        echo "No notes selected. Something went wrong."
        return 1
    end

    echo "=== INTERLEAVED REVIEW ($actual_count notes from $actual_count topics) ==="
    echo ""
    echo "  Each note is from a DIFFERENT topic."
    echo "  The context-switching is the point — it forces your brain"
    echo "  to discriminate between approaches, not just repeat one."
    echo ""

    set -l i 0
    for f in $selected
        set i (math $i + 1)
        set -l rel (string replace "$NOTES_DIR/" "" "$f")
        set -l bucket (basename (string replace "$NOTES_DIR/learning/" "" "$f" | string replace -r '/.*' ''))
        echo "  [$i/$actual_count] [$bucket] $rel"
    end
    echo ""

    read -P "Press Enter to start reviewing... " -l _

    for f in $selected
        set -l rel (string replace "$NOTES_DIR/" "" "$f")
        echo ""
        echo "--- Opening: $rel ---"
        $EDITOR "$f"

        if test "$f" != "$selected[-1]"
            read -P "Next note? [Enter to continue, q to stop] " -l response
            # WHY: trim whitespace and accept Q/q — user may type " q " or "Q" (Sweep audit)
            set response (string trim "$response")
            if string match -qir '^q$' "$response"
                echo "Stopped."
                return 0
            end
        end
    end

    echo ""
    echo "=== SESSION COMPLETE ==="
    echo "  Reviewed $actual_count notes across $actual_count distinct topics."
end
