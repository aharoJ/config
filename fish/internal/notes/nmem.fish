# path: ~/.config/fish/internal/notes/nmem.fish
# description: Meaningful memorization: memorize core facts, then build understanding.
# science: Kember (2016) East Asian intermediate learning approach, cognitive load theory (Sweller 1988)
# date: 2026-02-24
function nmem --description "notes: meaningful memorization"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nmem <topic>"
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l dir "$NOTES_DIR/learning/memorize"
    set -l file "$dir/$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Memorize First: $argv" >"$file"
        echo "" >>"$file"
        echo "_Created: $day_" >>"$file"
        echo "" >>"$file"
        echo "## Phase 1: Core facts to memorize (no understanding needed yet)" >>"$file"
        echo "" >>"$file"
        echo "1. " >>"$file"
        echo "2. " >>"$file"
        echo "3. " >>"$file"
        echo "" >>"$file"
        echo "## Phase 2: Now explain WHY each fact is true" >>"$file"
        echo "" >>"$file"
        echo "## Phase 3: Apply - solve a problem using these facts" >>"$file"
        echo "" >>"$file"
        echo "## Self-test" >>"$file"
        echo "Date tested: " >>"$file"
        echo "Score: /  correct" >>"$file"
        echo "" >>"$file"
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
