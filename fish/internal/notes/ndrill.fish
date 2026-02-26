# path: ~/.config/fish/internal/notes/ndrill.fish
# description: Flashcard drill from your notes. Implements active recall via self-testing.
# science: Roediger & Karpicke (2006) testing effect, Slamecka & Graf (1978) generation effect
# date: 2026-02-24
function ndrill --description "notes: flashcard drill"
    set -l deck_dir "$NOTES_DIR/learning/drills"
    mkdir -p "$deck_dir"

    if test (count $argv) -eq 0
        echo "Usage:"
        echo "  ndrill add <deck> <question> :: <answer>    Add a card"
        echo "  ndrill run <deck>                           Drill a deck"
        echo "  ndrill list                                 List all decks"
        echo "  ndrill from <file>                          Generate cards from note headings"
        return 1
    end

    set -l cmd $argv[1]

    switch $cmd
        case add
            if test (count $argv) -lt 3
                echo "Usage: ndrill add <deck> <question> :: <answer>"
                return 1
            end
            set -l deck $argv[2]
            set -l content (string join ' ' $argv[3..-1])
            set -l question (echo $content | sed 's/ :: .*//')
            set -l answer (echo $content | sed 's/.* :: //')
            set -l file "$deck_dir/$deck.md"

            if not test -f "$file"
                echo "# Drill Deck: $deck" >"$file"
                echo "" >>"$file"
            end

            echo "Q: $question" >>"$file"
            echo "A: $answer" >>"$file"
            echo "" >>"$file"
            echo "Card added to deck: $deck"

        case run
            if test (count $argv) -lt 2
                echo "Usage: ndrill run <deck>"
                return 1
            end
            set -l deck $argv[2]
            set -l file "$deck_dir/$deck.md"

            if not test -f "$file"
                echo "Deck '$deck' not found."
                return 1
            end

            set -l questions (grep '^Q: ' "$file")
            set -l answers (grep '^A: ' "$file")
            set -l total (count $questions)
            set -l correct 0
            set -l missed 0

            echo "=== DRILL: $deck ($total cards) ==="
            echo "For each question, try to answer BEFORE pressing Enter."
            echo ""

            for i in (seq 1 $total)
                echo "[$i/$total] $questions[$i]"
                read -P "  Your answer (press Enter to reveal): "
                echo "  $answers[$i]"
                read -P "  Got it right? [y/n]: " -l result
                if test "$result" = "y"
                    set correct (math $correct + 1)
                else
                    set missed (math $missed + 1)
                end
                echo ""
            end

            echo "=== Results: $correct/$total correct ==="
            if test $missed -gt 0
                echo "Review the $missed missed cards again soon (tomorrow)."
            end

        case list
            echo "=== Drill Decks ==="
            for f in $deck_dir/*.md
                if test -f "$f"
                    set -l name (basename $f .md)
                    set -l count (grep -c '^Q: ' "$f")
                    echo "  $name ($count cards)"
                end
            end

        case from
            if test (count $argv) -lt 2
                echo "Usage: ndrill from <file>"
                echo "Extracts headings from a note and creates question stubs."
                return 1
            end
            set -l source $argv[2]
            if not test -f "$NOTES_DIR/$source"
                set source (find "$NOTES_DIR" -name "*$source*" -path '*.md' | head -1)
            end
            if not test -f "$source"
                echo "File not found."
                return 1
            end
            echo "=== Headings from: "(basename $source)" ==="
            echo "For each heading, write a Q&A card with: ndrill add <deck> <Q> :: <A>"
            echo ""
            grep '^#' "$source" | while read -l heading
                set -l clean (echo $heading | sed 's/^#* //')
                echo "  Topic: $clean"
                echo "    Suggested Q: What is $clean? / Why does $clean matter? / How does $clean work?"
            end

        case '*'
            echo "Unknown command: $cmd"
            return 1
    end
end
