# path: ~/.config/fish/internal/notes/nteach.fish
# description: Teach-aloud protocol. Verbalize understanding to expose gaps.
# science: Chi et al. (1989) self-explanation effect, Roscoe & Chi (2007)
#          explaining to others vs. self, Fiorella & Mayer (2016) generative learning
# date: 2026-02-24
function nteach --description "notes: teach-aloud protocol"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nteach <concept>"
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/teach"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Teach: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## Pre-teach: what do I think I know? (bullet points)" >>"$file"
        echo "" >>"$file"
        echo "## I just taught this aloud for 2 minutes. Where did I stumble?" >>"$file"
        echo "" >>"$file"
        echo "## The question I could not answer mid-explanation" >>"$file"
        echo "" >>"$file"
        echo "## After research: what was I wrong about?" >>"$file"
        echo "" >>"$file"
        echo "## Teach attempt #2 summary (1 paragraph)" >>"$file"
        echo "" >>"$file"
    end

    echo "=== TEACH-ALOUD PROTOCOL ==="
    echo ""
    echo "1. Set a 2-minute timer."
    echo "2. Explain '$argv' OUT LOUD to nobody."
    echo "3. Notice: where do you pause? where do you hand-wave?"
    echo "4. Those pauses ARE your knowledge gaps."
    echo "5. Write them down. Research. Teach again."
    echo ""

    read -P "Press Enter after teaching aloud... "
    cd "$NOTES_DIR"; and $EDITOR "$file"
end
