# path: ~/.config/fish/internal/notes/integrate/ninterleave.fish
# description: Interleaved practice. Randomly selects N notes from DIFFERENT topics
#              and opens them in sequence. The forced context-switching between unrelated
#              topics creates discriminative contrast — you have to figure out WHICH
#              approach applies, not just execute one approach repeatedly.
# science: Taylor & Rohrer (2010) interleaving improved math performance d≈0.5-1.21,
#          Kornell & Bjork (2008) interleaving improves inductive learning,
#          Bjork (1994) desirable difficulties — interleaving is harder but better
# date: 2026-02-26
function ninterleave --description "notes: interleaved mixed-topic review"
    __notes_require; or return 1

    # WHY: default to 3 notes — enough for cross-topic contrast,
    # not so many that it becomes a slog
    set -l count 3
    if test (count $argv) -ge 1
        if string match -qr '^[0-9]+$' "$argv[1]"
            set count $argv[1]
        end
    end

    # WHY: collect notes from learning subdirectories only (not journal, not secret)
    # these are the notes with actual study content worth interleaving
    set -l candidates

    for subdir in why struggle recall errors drills
        set -l dir "$NOTES_DIR/learning/$subdir"
        if test -d "$dir"
            for f in (find "$dir" -name '*.md' 2>/dev/null)
                set candidates $candidates "$f"
            end
        end
    end

    if test (count $candidates) -lt $count
        echo "Not enough notes for interleaving."
        echo "Found "(count $candidates)" notes, need at least $count."
        echo ""
        echo "Keep studying. Interleaving works best with 10+ notes across topics."
        return 1
    end

    # WHY: random shuffle then take N — ensures different mix each session
    # the randomness IS the mechanism (desirable difficulty)
    # NOTE: shuf is GNU coreutils, not available on stock macOS.
    # awk + rand() is POSIX-portable and works everywhere.
    set -l selected (printf '%s\n' $candidates | awk 'BEGIN{srand()}{print rand()"\t"$0}' | sort -n | cut -f2- | head -n $count)

    echo "=== INTERLEAVED REVIEW ($count notes) ==="
    echo ""
    echo "  These notes are from different topics."
    echo "  The context-switching is the point — it forces your brain"
    echo "  to discriminate between approaches, not just repeat one."
    echo ""

    set -l i 0
    for f in $selected
        set i (math $i + 1)
        set -l rel (string replace "$NOTES_DIR/" "" "$f")
        echo "  [$i/$count] $rel"
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
            if test "$response" = "q"
                echo "Stopped."
                return 0
            end
        end
    end

    echo ""
    echo "=== SESSION COMPLETE ==="
    echo "  Reviewed $count notes across topics."
end
