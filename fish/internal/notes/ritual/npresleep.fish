# path: ~/.config/fish/internal/notes/ritual/npresleep.fish
# description: Queue notes for review just before sleep. The protocol includes
#              telling yourself "I will be tested on this tomorrow" — this expectation
#              measurably enhances overnight hippocampal consolidation. NOT retrieval
#              practice — the mechanism is priming consolidation, not testing recall.
# science: Wilhelm et al. (2011) expectancy enhances sleep-dependent memory consolidation,
#          Rasch et al. (2007) hippocampal replay during slow-wave sleep,
#          Diekelmann et al. (2013) sleep selectively consolidates expected-relevant memories
# date: 2026-02-26
function npresleep --description "notes: pre-sleep review queue (expectation priming)"
    __notes_require; or return 1

    set -l queue_file "$NOTES_DIR/.presleep-queue"
    set -l today (date +%Y-%m-%d)

    if test (count $argv) -eq 0
        # WHY: no args = run the review session
        _npresleep_review
        return $status
    end

    switch $argv[1]
        case add
            # WHY: add a note to tonight's review queue
            if test (count $argv) -lt 2
                echo "Usage: npresleep add <note-path>"
                return 1
            end
            _npresleep_add $argv[2..-1]

        case clear
            # WHY: reset the queue (e.g., after completing a session)
            if test -f "$queue_file"
                rm "$queue_file"
                echo "  Queue cleared."
            else
                echo "  Queue is already empty."
            end

        case list
            _npresleep_list

        case '*'
            echo "Usage:"
            echo "  npresleep                  Run the pre-sleep review"
            echo "  npresleep add <note>       Add a note to the queue"
            echo "  npresleep list             Show queued notes"
            echo "  npresleep clear            Clear the queue"
    end
end

# --- internal: add a note to the queue ---
function _npresleep_add
    set -l queue_file "$NOTES_DIR/.presleep-queue"
    set -l note_path (string join ' ' $argv)

    # WHY: resolve relative paths against NOTES_DIR
    if not test -f "$note_path"
        if test -f "$NOTES_DIR/$note_path"
            set note_path "$NOTES_DIR/$note_path"
        else
            echo "Note not found: $note_path"
            return 1
        end
    end

    # WHY: prevent duplicate entries in the queue
    if test -f "$queue_file"
        if grep -qF "$note_path" "$queue_file"
            echo "  Already in queue: "(basename "$note_path")
            return 0
        end
    end

    echo "$note_path" >>"$queue_file"
    echo "  Queued for pre-sleep review: "(basename "$note_path")
end

# --- internal: list queued notes ---
function _npresleep_list
    set -l queue_file "$NOTES_DIR/.presleep-queue"

    if not test -f "$queue_file"; or test (wc -l <"$queue_file" | string trim) -eq 0
        echo "  Pre-sleep queue is empty."
        echo "  Add notes: npresleep add <note-path>"
        return 0
    end

    echo "=== PRE-SLEEP QUEUE ==="
    echo ""
    set -l i 0
    while read -l line
        set i (math $i + 1)
        echo "  $i. "(string replace "$NOTES_DIR/" "" "$line")
    end <"$queue_file"
    echo ""
end

# --- internal: run the pre-sleep review session ---
function _npresleep_review
    set -l queue_file "$NOTES_DIR/.presleep-queue"

    if not test -f "$queue_file"; or test (wc -l <"$queue_file" | string trim) -eq 0
        echo "  Pre-sleep queue is empty."
        echo ""
        echo "  Quick add: npresleep add <note-path>"
        echo "  Or review today's learning notes:"
        echo ""

        # WHY: fallback — show today's learning notes as candidates
        set -l today (date +%Y-%m-%d)
        set -l todays_notes (find "$NOTES_DIR/learning" -name "$today-*.md" 2>/dev/null)
        if test (count $todays_notes) -gt 0
            for f in $todays_notes
                echo "    "(string replace "$NOTES_DIR/" "" "$f")
            end
        else
            echo "    (no learning notes from today)"
        end
        return 0
    end

    set -l notes (cat "$queue_file")
    set -l total (count $notes)

    echo "=== PRE-SLEEP REVIEW ==="
    echo ""
    echo "  $total note(s) queued."
    echo ""
    echo "  PROTOCOL:"
    echo "    1. Review each note briefly."
    echo "    2. After each, tell yourself:"
    echo "       \"I will be tested on this tomorrow.\""
    echo "    3. The expectation itself enhances overnight consolidation."
    echo ""

    read -P "Ready to begin? [Enter] " -l _

    for f in $notes
        if not test -f "$f"
            echo "  Skipping (file not found): $f"
            continue
        end

        set -l rel (string replace "$NOTES_DIR/" "" "$f")
        echo ""
        echo "--- Reviewing: $rel ---"
        $EDITOR "$f"

        echo ""
        echo "  Say to yourself: \"I will be tested on this tomorrow.\""
        read -P "  [Enter for next note] " -l _
    end

    echo ""
    echo "=== PRE-SLEEP REVIEW COMPLETE ==="
    echo "  $total note(s) reviewed."
    echo "  Sleep will consolidate these. Morning recall will test them."
    echo ""

    # WHY: clear the queue after a completed session — prevents stale entries
    rm "$queue_file"
end
