# path: ~/.config/fish/internal/notes/ninterleave.fish
# description: Interleaved review: randomly mixes notes across topics.
# science: Taylor & Rohrer (2010) interleaving, Bjork (1994) desirable difficulties, Kornell et al. inductive learning
# date: 2026-02-24
function ninterleave --description "notes: interleaved review"
    __notes_require; or return 1

    set -l count 5
    if test (count $argv) -ge 1
        set count $argv[1]
    end

    set -l all_notes (
        find "$NOTES_DIR" -type f -name "*.md" \
            -not -path '*/.git/*' \
            -not -path '*/secret/*' \
            -not -path '*/templates/*' \
            -not -path '*/reviews/*'
    )

    if test (count $all_notes) -eq 0
        echo "No notes found."
        return 1
    end

    # Random sample: gshuf (macOS coreutils) > shuf (GNU) > python3 > python
    set -l picked
    if type -q gshuf
        set picked (printf "%s\n" $all_notes | gshuf | head -n $count)
    else if type -q shuf
        set picked (printf "%s\n" $all_notes | shuf | head -n $count)
    else if type -q python3
        set picked (printf "%s\n" $all_notes | python3 -c '
import sys, random
n=int(sys.argv[1])
lines=[l.strip() for l in sys.stdin if l.strip()]
random.shuffle(lines)
print("\n".join(lines[:n]))
' $count)
    else if type -q python
        set picked (printf "%s\n" $all_notes | python -c '
import sys, random
n=int(sys.argv[1])
lines=[l.strip() for l in sys.stdin if l.strip()]
random.shuffle(lines)
print("\n".join(lines[:n]))
' $count)
    else
        echo "Need one of: shuf / gshuf / python3 / python for random sampling."
        return 1
    end

    if test (count $picked) -eq 0
        echo "Could not sample notes."
        return 1
    end

    echo "=== INTERLEAVED REVIEW ($count random notes) ==="
    echo ""
    echo "These notes are from DIFFERENT topics on purpose."
    echo "Switching between topics forces deeper processing."
    echo "It feels harder. That means it is working."
    echo ""

    set -l i 0
    for note in $picked
        set i (math $i + 1)
        set -l relative (string replace "$NOTES_DIR/" "" -- "$note")
        echo "[$i] $relative"
    end

    echo ""
    echo "--- PROTOCOL ---"
    echo "1) Recall BEFORE opening each note"
    echo "2) After reading, ask: how does this connect to the OTHER notes?"
    echo "3) Unexpected connections = real learning"
    echo ""

    read -P "Press Enter to begin... "
    for note in $picked
        $EDITOR "$note"
    end
end
