# path: ~/.config/fish/internal/notes/retrieve/nleitner.fish
# description: Leitner box SRS flashcard system. One engine for card creation, spaced
#              drilling, and fluency tracking. Cards move between 5 boxes with increasing
#              review intervals (1/3/7/14/30 days). Wrong answers demote to box 1.
# science: Leitner (1972) adaptive spacing — hard cards reviewed more, easy cards less,
#          Cepeda et al. (2006) meta-analysis of 254 studies on distributed practice,
#          Roediger & Karpicke (2006) testing effect,
#          Anderson (1982) knowledge compilation — fluency (speed) indicates mastery
# absorbed: ndrill.fish (card creation: add, from — same flashcard system),
#           ntimed.fish (speed tracking — fluency is a feature, not a function)
# patched: 2026-02-26
#   - fix: per-card due dates instead of day-of-year modulo (ChatGPT + DeepSeek audit)
#   - fix: state reconciliation when cards added/removed (ChatGPT audit)
#   - fix: avg_time math — \$due_indices in quotes was literal string (Claude audit)
#   - fix: `from` preserves blank-line separators between cards (Claude audit)
#   - fix: Box 5 promotion no-op handled gracefully (Kimi audit)
#   - fix: math "min($total, (count \$boxes))" — nested command substitution
#     inside math quotes produces literal string, not a number. Pre-compute
#     count before math call (Claude + Kimi second-pass audit)
#   - fix: status now calls reconcile first — stale state made box counts and
#     mastery percentage lie after deck edits (ChatGPT second-pass audit)
#   - fix: reconcile truncates state when deck shrinks — stale rows persisted
#     forever because run/status never cleaned them (ChatGPT second-pass audit)
#   - state format: one line per card, "BOX NEXT_DUE" (e.g., "1 2026-02-27")
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

    # WHY: mkdir can fail on permission errors — check return status (Sweep audit)
    if not mkdir -p "$deck_dir" "$state_dir" 2>/dev/null
        echo "Error: could not create deck directories under $NOTES_DIR"
        return 1
    end

    switch $cmd
        case add
            if test (count $argv) -lt 2; or test -z "$argv[2]"
                echo "Usage: nleitner add <deck>"
                return 1
            end
            _nleitner_add $argv[2]

        case from
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

# --- helper: compute next_due date from today + N days (cross-platform) ---
function _nleitner_date_add
    set -l days $argv[1]
    # WHY: macOS uses -v+Nd, GNU/Linux uses -d '+N days'
    set -l result (date -v+"$days"d +%Y-%m-%d 2>/dev/null)
    if test $status -ne 0
        set result (date -d "+$days days" +%Y-%m-%d 2>/dev/null)
    end
    # WHY: if both date forms fail, fall back to today — prevents empty due dates
    # which would corrupt state file (Sweep audit)
    if test -z "$result"
        set result (date +%Y-%m-%d)
    end
    echo "$result"
end

# --- helper: interval days for a given box ---
function _nleitner_interval
    switch $argv[1]
        case 1; echo 1
        case 2; echo 3
        case 3; echo 7
        case 4; echo 14
        case 5; echo 30
        case '*'; echo 1
    end
end

# --- internal: add a single card interactively ---
function _nleitner_add
    set -l deck $argv[1]

    # WHY: reject deck names with slashes or dots to prevent path traversal
    # "../../etc/foo" would write outside NOTES_DIR (Sweep audit pass 2)
    if string match -qr '[/\\.]' "$deck"
        echo "  Error: deck name cannot contain slashes or dots: $deck"
        return 1
    end

    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l file "$deck_dir/$deck.md"

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
    echo "  Run 'nleitner init $deck' to reset state, or new cards auto-reconcile on next run."
end

# --- internal: extract Q&A pairs from a note ---
function _nleitner_from
    set -l deck $argv[1]

    # WHY: reject deck names with slashes or dots to prevent path traversal (Sweep audit)
    if string match -qr '[/\\.]' "$deck"
        echo "  Error: deck name cannot contain slashes or dots: $deck"
        return 1
    end

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

    # WHY: extract existing Q:/A: pairs from the note, preserving separators
    # previous version stripped blank lines between cards (Claude audit)
    set -l found (grep -c '^Q: ' "$note_path" 2>/dev/null)
    if test "$found" -gt 0
        grep '^[QA]: ' "$note_path" | while read -l line
            echo "$line" >>"$file"
            # WHY: add blank line after each A: line to preserve card boundaries
            if string match -q 'A: *' "$line"
                echo "" >>"$file"
            end
        end
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

    # WHY: state format is "BOX NEXT_DUE" per line — one line per card
    # all cards start in box 1, due today (immediate first drill)
    set -l today (date +%Y-%m-%d)
    echo -n "" >"$state"
    for i in (seq 1 $total)
        echo "1 $today" >>"$state"
    end

    echo "  Leitner state initialized for '$deck': $total cards, all in Box 1, due today."
end

# --- internal: reconcile state with deck (auto-fix drift) ---
# WHY: if cards are added/removed after init, state and deck go out of sync.
# this reconciles by appending new entries or TRUNCATING stale rows (ChatGPT audit).
# NOTE: state is positional (row N = card N). Reordering or inserting cards in the
# middle of a deck will mismatch state. For now, the minimum fix is truncation.
# A future improvement would store per-card identity (hash of Q+A) in the state file.
function _nleitner_reconcile
    set -l deck $argv[1]
    set -l deck_dir "$NOTES_DIR/learning/drills"
    set -l state_dir "$NOTES_DIR/learning/leitner"
    set -l file "$deck_dir/$deck.md"
    set -l state "$state_dir/$deck.state"

    set -l card_count (grep -c '^Q: ' "$file")
    set -l state_count (wc -l <"$state" | string trim)

    if test "$card_count" -eq "$state_count"
        return 0
    end

    if test "$card_count" -gt "$state_count"
        # WHY: new cards added — append them as box 1, due today
        set -l diff (math "$card_count - $state_count")
        set -l today (date +%Y-%m-%d)
        for i in (seq 1 $diff)
            echo "1 $today" >>"$state"
        end
        echo "  Reconciled: $diff new card(s) added to state (Box 1, due today)."
    else
        # WHY: cards removed — state has stale rows. Truncate to match deck size.
        # old behavior: warn and continue, leaving stale rows that _nleitner_run
        # would write back out and _nleitner_status would count (ChatGPT second-pass)
        set -l diff (math "$state_count - $card_count")
        echo "  Warning: $diff card(s) removed from deck. Truncating state to match."
        echo "  (State is positional — if you reordered cards, run 'nleitner init' instead.)"
        # WHY: head -n is portable truncation — overwrite state with only card_count lines
        set -l tmp (mktemp)
        head -n "$card_count" "$state" >"$tmp"
        mv "$tmp" "$state"
    end
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

    # WHY: reconcile state with deck before drilling
    _nleitner_reconcile $deck; or return 1

    set -l questions (grep '^Q: ' "$file" | sed 's/^Q: //')
    set -l answers (grep '^A: ' "$file" | sed 's/^A: //')
    set -l total (count $questions)

    if test $total -eq 0
        echo "No cards in deck: $deck"
        return 0
    end

    # WHY: Q and A counts must match — mismatched pairs would display wrong answers
    # for the wrong questions. Fail fast instead of silently corrupting drill (Sweep audit)
    if test (count $answers) -ne $total
        echo "Error: Q/A count mismatch in deck '$deck' — "(count $questions)" questions, "(count $answers)" answers."
        echo "Check the deck file for missing or extra Q:/A: lines."
        return 1
    end

    # WHY: read state into parallel arrays — BOX and NEXT_DUE per card
    set -l boxes
    set -l due_dates
    while read -l line
        set -l parts (string split ' ' "$line")
        set boxes $boxes $parts[1]
        set due_dates $due_dates $parts[2]
    end <"$state"

    set -l today (date +%Y-%m-%d)
    set -l due_indices

    # WHY: pre-compute count before math — nested (count \$boxes) inside
    # a math "..." string produces a literal string, not a number.
    # Same root cause as the avg_time bug (Claude + Kimi second-pass audit)
    set -l box_count (count $boxes)
    set -l limit (math "min($total, $box_count)")

    # WHY: compare per-card due date against today — true interval-based scheduling
    # replaces day-of-year modulo which was calendar-dependent (ChatGPT + DeepSeek audit)
    for i in (seq 1 $limit)
        # WHY: Fish test has no <= operator — \<= is invalid and always fails.
        # Use negated > instead: "not greater than" = "less than or equal".
        # String comparison works for ISO dates (YYYY-MM-DD) (Sweep audit pass 1+2)
        if not test "$due_dates[$i]" \> "$today"
            set due_indices $due_indices $i
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
    set -l card_num 0

    for idx in $due_indices
        set card_num (math $card_num + 1)
        set -l box $boxes[$idx]
        echo "[$card_num/"(count $due_indices)"] (box $box) $questions[$idx]"

        # WHY: track response time — fluency indicates knowledge compilation (Anderson 1982)
        set -l start_time (date +%s)
        read -P "  Your answer: " -l _user_answer
        set -l end_time (date +%s)
        set -l elapsed (math "$end_time - $start_time")
        set total_time (math "$total_time + $elapsed")

        echo "  → $answers[$idx]"

        read -P "  Correct? [y/n]: " -l result

        if test "$result" = "y"
            set correct (math $correct + 1)

            if test $box -eq 5
                # WHY: already mastered — stay in box 5, reschedule (Kimi audit)
                set -l interval (_nleitner_interval 5)
                set due_dates[$idx] (_nleitner_date_add $interval)
                if test $elapsed -le 3
                    echo "  ✓ Mastered ($elapsed"s") — Box 5, next: $due_dates[$idx]"
                else
                    echo "  ✓ ($elapsed"s") — Box 5, next: $due_dates[$idx]"
                end
            else
                set -l new_box (math "$box + 1")
                set boxes[$idx] $new_box
                set -l interval (_nleitner_interval $new_box)
                set due_dates[$idx] (_nleitner_date_add $interval)
                if test $elapsed -le 3
                    echo "  ✓ Fast ($elapsed"s") → Box $new_box, next: $due_dates[$idx]"
                else
                    echo "  ✓ ($elapsed"s") → Box $new_box, next: $due_dates[$idx]"
                end
            end
        else
            set wrong (math $wrong + 1)
            # WHY: demote to box 1, due tomorrow — Leitner's core rule
            set boxes[$idx] 1
            set due_dates[$idx] (_nleitner_date_add 1)
            echo "  ✗ → Box 1, next: $due_dates[$idx]"
        end
        echo ""
    end

    # WHY: write updated state back to file
    set -l tmp (mktemp)
    for i in (seq 1 (count $boxes))
        echo "$boxes[$i] $due_dates[$i]" >>"$tmp"
    end
    mv "$tmp" "$state"

    # WHY: compute avg_time correctly — previous version used \$due_indices inside
    # double quotes which Fish treated as literal string → count always returned 1 (Claude audit)
    set -l due_count (count $due_indices)
    set -l avg_time 0
    if test $due_count -gt 0
        set avg_time (math "round($total_time / $due_count)")
    end

    echo "=== SESSION COMPLETE ==="
    echo "  Correct: $correct / $due_count"
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

    # WHY: reconcile BEFORE reading state — otherwise stale rows from removed
    # cards inflate box counts and mastery percentage (ChatGPT second-pass audit)
    _nleitner_reconcile $deck

    # WHY: read state into arrays
    set -l boxes
    set -l due_dates
    while read -l line
        set -l parts (string split ' ' "$line")
        set boxes $boxes $parts[1]
        set due_dates $due_dates $parts[2]
    end <"$state"

    set -l today (date +%Y-%m-%d)

    echo "=== LEITNER STATUS: $deck ==="
    echo "  Total cards: $total"
    echo ""

    # WHY: count cards per box
    for box_num in 1 2 3 4 5
        set -l box_interval
        switch $box_num
            case 1; set box_interval "1 day"
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

        set -l bar (string repeat -n $count "█")
        echo "  Box $box_num ($box_interval): $count $bar"
    end
    echo ""

    # WHY: count due cards
    set -l due_count 0
    for i in (seq 1 (count $due_dates))
        if not test "$due_dates[$i]" \> "$today"
            set due_count (math $due_count + 1)
        end
    end
    echo "  Due today: $due_count"

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
            set -l cards (grep -c '^Q: ' "$f" 2>/dev/null)
            set -l state_file "$NOTES_DIR/learning/leitner/$name.state"
            if test -f "$state_file"
                echo "  $name ($cards cards, Leitner active)"
            else
                echo "  $name ($cards cards, not initialized)"
            end
        end
    end
end
