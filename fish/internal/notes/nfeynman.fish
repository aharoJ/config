# path: ~/.config/fish/internal/notes/nfeynman.fish
# description: Feynman technique -- explain a concept in plain language to expose gaps.
# science: Slamecka & Graf (1978) generation effect, elaborative interrogation (Pressley 1988)
# date: 2026-02-24
function nfeynman --description "notes: Feynman explanation note"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nfeynman <concept>"
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/feynman"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Feynman: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day_" >>"$file"
        echo "" >>"$file"
        echo "## Explain it like I am 12" >>"$file"
        echo "" >>"$file"
        echo "## Where did I get stuck or hand-wave?" >>"$file"
        echo "" >>"$file"
        echo "## Go back to the source. Fill the gaps." >>"$file"
        echo "" >>"$file"
        echo "## Explain it again, simpler" >>"$file"
        echo "" >>"$file"
        echo "## Analogy" >>"$file"
        echo "" >>"$file"
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
