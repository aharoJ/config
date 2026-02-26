# path: ~/.config/fish/internal/notes/nleitner.fish
# description: Leitner box SRS flashcard system. One engine for card creation, spaced
#              drilling, and fluency tracking. Cards move between 5 boxes with increasing
#              review intervals (1/3/7/14/30 days). Wrong answers demote to box 1.
# science: Leitner (1972) adaptive spacing — hard cards reviewed more, easy cards less,
#          Cepeda et al. (2006) meta-analysis of 254 studies on distributed practice,
#          Roediger & Karpicke (2006) testing effect,
#          Anderson (1982) knowledge compilation — fluency (speed) indicates mastery
# absorbed: ndrill.fish (card creation: add, from — same flashcard system),
#           ntimed.fish (speed tracking — fluency is a feature, not a function)
# date: 2026-02-26
function nleitner --description "notes: Leitner box flashcard SRS (create + drill + track)"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage:"
        echo "  nleitner add <deck>              Add a card to a deck"
        echo "  nleitner from <deck> <note>       Extract Q&A pairs from a note"
        echo "  nleitner run <deck>               Drill due cards (Leitner spacing)"
        echo "  nleitner status <deck>            Show box distribution + stats"
        echo "  nleitner init <deck>              Initialize Leitner state for a deck"
        echo "  nleitner list                     Show all decks"
        echo ""
        echo "Cards move through 5 boxes: 1→2→3→4→5 on correct."
        echo "Wrong answer → back to box 1. Review intervals: 1/3/7/14/30 days."
        return 1
    end

    set -l cmd $argv[1]
    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l state_dir "$NOTES_DIR/learning/leitner"
    mkdir -p "$deck_dir" "$state_dir"

    switch $cmd
        case add
            # WHY: absorbed from ndrill — card creation belongs with the card engine
            if test (count $argv) -lt 2
                echo "Usage: nleitner add <deck>"
                return 1
            end
            _nleitner_add $argv[2]

        case from
            # WHY: absorbed from ndrill — extract Q&A from existing notes
            if test (count $argv) -lt 3
                echo "Usage: nleitner from <deck> <note-path>"
                return 1
            end
            _nleitner_from $argv[2] $argv[3..-1]

        case run
            if test (count $argv) -lt 2
                echo "Usage: nleitner run <deck>"
                return 1
            end
            _nleitner_run $argv[2]

        case status
            if test (count $argv) -lt 2
                echo "Usage: nleitner status <deck>"
                return 1
            end
            _nleitner_status $argv[2]

        case init
            if test (count $argv) -lt 2
                echo "Usage: nleitner init <deck>"
                return 1
            end
            _nleitner_init $argv[2]

        case list
            _nleitner_list

        case '*'
            echo "Unknown command: $cmd"
            echo "Run 'nleitner' for usage."
            return 1
    end
end

# --- internal: add a single card interactively ---
function _nleitner_add
    set -l deck $argv[1]
    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l file "$deck_dir/$deck.md"

    # WHY: create deck file if it doesn't exist
    if not test -f "$file"
        echo "# Deck: $deck" >"$file"
        echo "" >>"$file"
    end

    echo "=== ADD CARD TO: $deck ==="
    echo ""
    read -P "  Q: " -l question
    if test -z "$question"
        echo "  Cancelled — empty question."
        return 1
    end
    read -P "  A: " -l answer
    if test -z "$answer"
        echo "  Cancelled — empty answer."
        return 1
    end

    echo "Q: $question" >>"$file"
    echo "A: $answer" >>"$file"
    echo "" >>"$file"

    set -l count (grep -c '^Q: ' "$file")
    echo ""
    echo "  Card added. Deck now has $count card(s)."
    echo "  Add another? Run: nleitner add $deck"
end

# --- internal: extract Q&A pairs from a note ---
function _nleitner_from
    set -l deck $argv[1]
    set -l note_path (string join ' ' $argv[2..-1])
    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l file "$deck_dir/$deck.md"

    # WHY: resolve path relative to NOTES_DIR
    if not test -f "$note_path"
        if test -f "$NOTES_DIR/$note_path"
            set note_path "$NOTES_DIR/$note_path"
        else
            echo "Note not found: $note_path"
            return 1
        end
    end

    if not test -f "$file"
        echo "# Deck: $deck" >"$file"
        echo "" >>"$file"
    end

    # WHY: extract existing Q:/A: pairs from the note
    set -l found (grep -c '^Q: ' "$note_path" 2>/dev/null)
    if test "$found" -gt 0
        grep '^[QA]: ' "$note_path" >>"$file"
        echo "" >>"$file"
        echo "  Extracted $found card(s) from "(basename "$note_path")" → $deck"
    else
        echo "  No Q:/A: pairs found in "(basename "$note_path")
        echo "  Format cards as:"
        echo "    Q: What is X?"
        echo "    A: X is Y."
    end
end

# --- internal: initialize Leitner state ---
function _nleitner_init
    set -l deck $argv[1]
    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l state_dir "$NOTES_DIR/learning/leitner"
    set -l file "$deck_dir/$deck.md"
    set -l state "$state_dir/$deck.state"

    if not test -f "$file"
        echo "Deck '$deck' not found. Create cards first: nleitner add $deck"
        return 1
    end

    set -l total (grep -c '^Q: ' "$file")

    if test $total -eq 0
        echo "Deck '$deck' has no cards."
        return 1
    end

    # WHY: state file tracks box assignment for each card (1-indexed)
    # format: one line per card, each line is the box number (1-5)
    # all cards start in box 1
    echo -n "" >"$state"
    for i in (seq 1 $total)
        echo "1" >>"$state"
    end

    echo "  Leitner state initialized for '$deck': $total cards, all in Box 1."
end

# --- internal: run a Leitner drill session ---
function _nleitner_run
    set -l deck $argv[1]
    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l state_dir "$NOTES_DIR/learning/leitner"
    set -l file "$deck_dir/$deck.md"
    set -l state "$state_dir/$deck.state"

    if not test -f "$file"
        echo "Deck '$deck' not found."
        return 1
    end

    # WHY: auto-init if no state exists
    if not test -f "$state"
        _nleitner_init $deck
    end

    set -l questions (grep '^Q: ' "$file" | sed 's/^Q: //')
    set -l answers (grep '^A: ' "$file" | sed 's/^A: //')
    set -l boxes (cat "$state")
    set -l total (count $questions)

    if test $total -eq 0
        echo "No cards in deck: $deck"
        return 0
    end

    # WHY: Leitner intervals — box N reviewed every N-th session
    # box 1 = every session, box 2 = every 3rd, box 3 = every 7th, etc.
    # simplified: we drill all cards in box 1 always, then probabilistically
    # include higher boxes. For a terminal tool, just drill box 1-2 always,
    # box 3+ based on day calculation.
    set -l today_num (date +%j | string trim --chars '0')
    set -l due_indices

    for i in (seq 1 $total)
        set -l box $boxes[$i]
        switch $box
            case 1
                # WHY: box 1 = every session (daily)
                set due_indices $due_indices $i
            case 2
                # WHY: box 2 = every 3 days
                if test (math "$today_num % 3") -eq 0
                    set due_indices $due_indices $i
                end
            case 3
                # WHY: box 3 = every 7 days
                if test (math "$today_num % 7") -eq 0
                    set due_indices $due_indices $i
                end
            case 4
                # WHY: box 4 = every 14 days
                if test (math "$today_num % 14") -eq 0
                    set due_indices $due_indices $i
                end
            case 5
                # WHY: box 5 = every 30 days
                if test (math "$today_num % 30") -eq 0
                    set due_indices $due_indices $i
                end
        end
    end

    if test (count $due_indices) -eq 0
        echo "No cards due today in '$deck'. All cards are in higher boxes."
        echo "Run 'nleitner status $deck' to see box distribution."
        return 0
    end

    echo "=== LEITNER DRILL: $deck ==="
    echo "  "(count $due_indices)" card(s) due today"
    echo ""

    set -l correct 0
    set -l wrong 0
    set -l total_time 0

    for idx in $due_indices
        set -l box $boxes[$idx]
        echo "[$correct+$wrong/"(count $due_indices)"] (box $box) $questions[$idx]"

        # WHY: track response time — fluency indicates knowledge compilation (Anderson 1982)
        # absorbed from ntimed.fish — speed is a feature, not a function
        set -l start_time (date +%s)
        read -P "  Your answer: " -l _user_answer
        set -l end_time (date +%s)
        set -l elapsed (math "$end_time - $start_time")
        set total_time (math "$total_time + $elapsed")

        echo "  → $answers[$idx]"

        read -P "  Correct? [y/n]: " -l result

        if test "$result" = "y"
            set correct (math $correct + 1)
            # WHY: promote to next box (max 5)
            set -l new_box (math "min($box + 1, 5)")
            set boxes[$idx] $new_box
            if test $elapsed -le 3
                echo "  ✓ Fast ($elapsed"s") → Box $new_box"
            else
                echo "  ✓ ($elapsed"s") → Box $new_box"
            end
        else
            set wrong (math $wrong + 1)
            # WHY: demote to box 1 — Leitner's core rule
            set boxes[$idx] 1
            echo "  ✗ → Box 1"
        end
        echo ""
    end

    # WHY: write updated box state back to file
    printf '%s\n' $boxes >"$state"

    set -l avg_time 0
    if test (count $due_indices) -gt 0
        set avg_time (math "round($total_time / (count \$due_indices))")
    end

    echo "=== SESSION COMPLETE ==="
    echo "  Correct: $correct / "(count $due_indices)
    echo "  Avg response time: "$avg_time"s"
    echo ""

    # WHY: fluency feedback — fast + correct = mastered
    if test $avg_time -le 3; and test $wrong -eq 0
        echo "  FLUENT — fast and accurate."
    else if test $wrong -eq 0
        echo "  ACCURATE — all correct, but could be faster."
    else
        echo "  KEEP DRILLING — $wrong card(s) reset to Box 1."
    end
end

# --- internal: show Leitner status ---
function _nleitner_status
    set -l deck $argv[1]
    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l state_dir "$NOTES_DIR/learning/leitner"
    set -l file "$deck_dir/$deck.md"
    set -l state "$state_dir/$deck.state"

    if not test -f "$file"
        echo "Deck '$deck' not found."
        return 1
    end

    set -l total (grep -c '^Q: ' "$file")

    if not test -f "$state"
        echo "  Deck '$deck': $total cards (not initialized)"
        echo "  Run: nleitner init $deck"
        return 0
    end

    set -l boxes (cat "$state")

    echo "=== LEITNER STATUS: $deck ==="
    echo "  Total cards: $total"
    echo ""

    # WHY: count cards per box
    for box_num in 1 2 3 4 5
        set -l box_interval
        switch $box_num
            case 1; set box_interval "daily"
            case 2; set box_interval "3 days"
            case 3; set box_interval "7 days"
            case 4; set box_interval "14 days"
            case 5; set box_interval "30 days"
        end

        set -l count 0
        for b in $boxes
            if test "$b" = "$box_num"
                set count (math $count + 1)
            end
        end

        # WHY: visual bar for quick scanning
        set -l bar (string repeat -n $count "█")
        echo "  Box $box_num ($box_interval): $count $bar"
    end
    echo ""

    # WHY: mastery metric — cards in box 4-5 are "learned"
    set -l mastered 0
    for b in $boxes
        if test "$b" -ge 4
            set mastered (math $mastered + 1)
        end
    end
    set -l pct 0
    if test $total -gt 0
        set pct (math "round($mastered / $total * 100)")
    end
    echo "  Mastery (box 4+): $mastered/$total ($pct%)"
end

# --- internal: list all decks ---
function _nleitner_list
    set -l deck_dir "$NOTES_DIR/learning/drills"

    if not test -d "$deck_dir"
        echo "No decks yet. Create one: nleitner add <deck-name>"
        return 0
    end

    echo "=== DECKS ==="
    echo ""
    for f in $deck_dir/*.md
        if test -f "$f"
            set -l name (basename "$f" .md)
            set -l cards (grep -c '^Q: ' "$f" 2>/dev/null; or echo 0)
            set -l state_file "$NOTES_DIR/learning/leitner/$name.state"
            if test -f "$state_file"
                echo "  $name ($cards cards, Leitner active)"
            else
                echo "  $name ($cards cards, not initialized)"
            end
        end
    end
end
