# path: ~/.config/fish/internal/notes/ndrill.fish
# description: Flashcard drill from your notes (Q/A).
# science: Roediger & Karpicke (2006) testing effect, Slamecka & Graf (1978) generation effect
# date: 2026-02-24
function ndrill --description "notes: flashcard drill"
    __notes_require; or return 1

    set -l deck_dir "$NOTES_DIR/learning/drills"
    mkdir -p "$deck_dir"

    if test (count $argv) -eq 0
        echo "Usage:"
        echo "  ndrill add <deck> <question> :: <answer>"
        echo "  ndrill run <deck>"
        echo "  ndrill list"
        echo "  ndrill from <file>"
        return 1
    end

    set -l cmd $argv[1]

    switch $cmd
        case add
            if test (count $argv) -lt 4
                echo "Usage: ndrill add <deck> <question> :: <answer>"
                return 1
            end

            set -l deck $argv[2]
            set -l content (string join ' ' $argv[3..-1])
            set -l parts (string split -m1 ' :: ' -- $content)

            if test (count $parts) -lt 2
                echo "ERROR: Missing delimiter ' :: '"
                echo "Example: ndrill add acct \"What is accrual?\" :: \"Recognize revenue when earned\""
                return 1
            end

            set -l question (string trim -- $parts[1])
            set -l answer (string trim -- $parts[2])
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

            set -l questions (rg --no-heading '^Q: ' "$file")
            set -l answers (rg --no-heading '^A: ' "$file")
            set -l total (count $questions)

            if test $total -eq 0
                echo "No cards in deck: $deck"
                return 0
            end

            set -l correct 0
            set -l missed 0

            echo "=== DRILL: $deck ($total cards) ==="
            echo "Answer BEFORE revealing."
            echo ""

            for i in (seq 1 $total)
                echo "[$i/$total] $questions[$i]"
                read -P "  (Press Enter to reveal) " -l _
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
                echo "Review missed cards again tomorrow."
            end

        case list
            echo "=== Drill Decks ==="
            for f in $deck_dir/*.md
                if test -f "$f"
                    set -l name (basename "$f" .md)
                    set -l count (rg -c '^Q: ' "$f")
                    echo "  $name ($count cards)"
                end
            end

        case from
            if test (count $argv) -lt 2
                echo "Usage: ndrill from <file>"
                return 1
            end

            set -l source $argv[2]
            if not test -f "$NOTES_DIR/$source"
                set source (find "$NOTES_DIR" -type f -iname "*$source*" -name "*.md" \
                    -not -path '*/.git/*' -not -path '*/secret/*' | head -1)
            else
                set source "$NOTES_DIR/$source"
            end

            if test -z "$source"; or not test -f "$source"
                echo "File not found."
                return 1
            end

            echo "=== Headings from: "(basename "$source")" ==="
            echo "Write Q/A cards with: ndrill add <deck> <Q> :: <A>"
            echo ""
            rg --no-heading '^#' "$source" | while read -l heading
                set -l clean (string replace -r '^#+\s*' '' -- "$heading")
                echo "  Topic: $clean"
                echo "    Suggested Q: What is $clean? / Why does $clean matter? / How does $clean work?"
            end

        case '*'
            echo "Unknown command: $cmd"
            return 1
    end
end
