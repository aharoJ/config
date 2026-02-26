# path: ~/.config/fish/internal/notes/ninterleave.fish
# description: Interleaved review: randomly mixes notes across topics.
# science: Taylor & Rohrer (2010) interleaving, Bjork (1994) desirable difficulties, Kornell et al. inductive learning
# date: 2026-02-24
function ninterleave --description "notes: interleaved review"
    set -l count 5
    if test (count $argv) -ge 1
        set count $argv[1]
    end

    set -l all_notes (find "$NOTES_DIR" -name '*.md' \
        -not -path '*/.git/*' \
        -not -path '*/secret/*' \
        -not -path '*/templates/*' \
        -not -path '*/reviews/*' \
        | shuf \
        | head -$count)

    if test (count $all_notes) -eq 0
        echo "No notes found."
        return 1
    end

    echo "=== INTERLEAVED REVIEW ($count random notes) ==="
    echo ""
    echo "These notes are from DIFFERENT topics on purpose."
    echo "Switching between topics forces deeper processing."
    echo "It feels harder. That means it is working."
    echo ""

    set -l i 0
    for note in $all_notes
        set i (math $i + 1)
        set -l relative (string replace "$NOTES_DIR/" "" "$note")
        echo "[$i] $relative"
    end

    echo ""
    echo "--- PROTOCOL ---"
    echo "1. For each note, recall what you can BEFORE opening it"
    echo "2. After reading, ask: How does this connect to the OTHER notes in this set?"
    echo "3. Finding unexpected connections = real learning"
    echo ""

    read -P "Press Enter to begin... "
    for note in $all_notes
        $EDITOR "$note"
    end
end
