# path: ~/.config/fish/internal/notes/nbody.fish
# description: Embodied learning prompt -- use your body to encode concepts.
# science: Macedonia & Knosche (2011) gesture + vocabulary retention (+0.73 SD),
#          Goldin-Meadow (2009) gesture + math transfer (+50%),
#          Lyu & Deng (2024) meta-analysis: embodied learning g=0.52
# date: 2026-02-24
function nbody --description "notes: embodied learning prompt"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nbody <concept>"
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/embodied"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Embodied: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## Stand up. Move away from the screen." >>"$file"
        echo "" >>"$file"
        echo "## Gesture: what hand motions represent this concept?" >>"$file"
        echo "<!-- Example: for a stack, push palm down then lift up -->" >>"$file"
        echo "<!-- Example: for recursion, spiral inward with finger -->" >>"$file"
        echo "" >>"$file"
        echo "## Walk-through: physically walk through the process" >>"$file"
        echo "<!-- Each step = one physical step. Speak each step aloud. -->" >>"$file"
        echo "" >>"$file"
        echo "## Spatial layout: arrange objects to represent the structure" >>"$file"
        echo "<!-- Use cups, pens, books, anything physical -->" >>"$file"
        echo "" >>"$file"
        echo "## Teach it to the wall using only gestures and speech (no screen)" >>"$file"
        echo "" >>"$file"
        echo "## What did the physical encoding reveal?" >>"$file"
        echo "" >>"$file"
    end

    echo "=== EMBODIED LEARNING ==="
    echo ""
    echo "STEP 1: Stand up. Step away from the keyboard."
    echo "STEP 2: Use your hands to represent the concept."
    echo "STEP 3: Walk through the process physically."
    echo "STEP 4: Explain it aloud to the wall."
    echo "STEP 5: Come back and write what you noticed."
    echo ""
    echo "Your body recruits neural pathways your screen never will."
    echo ""

    read -P "Press Enter after physical encoding... "
    cd "$NOTES_DIR"; and $EDITOR "$file"
end
