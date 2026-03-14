# path: ~/.config/fish/internal/notes/ritual/npresleep.fish
# description: Queue notes for review just before sleep. The protocol includes
#              telling yourself "I will be tested on this tomorrow" — this expectation
#              measurably enhances overnight hippocampal consolidation. NOT retrieval
#              practice — the mechanism is priming consolidation, not testing recall.
# science: Wilhelm et al. (2011) expectancy enhances sleep-dependent memory consolidation,
#          Rasch et al. (2007) hippocampal replay during slow-wave sleep,
#          Diekelmann et al. (2013) sleep selectively consolidates expected-relevant memories
# patched: 2026-02-26
#   - fix: exact-line duplicate check with grep -qxF not -qF (ChatGPT audit)
#   - fix: preserve queue on incomplete session / Ctrl+C (Kimi audit)
#   - fix: filter blank lines from queue to prevent ghost entries (Claude audit)
# date: 2026-02-26
function npresleep --description "notes: pre-sleep review queue (expectation priming)"
    __notes_require; or return 1

    set -l queue_file "$NOTES_DIR/.presleep-queue"

    if test (count $argv) -eq 0
        _npresleep_review
        return $status
    end

    switch $argv[1]
        case add
            if test (count $argv) -lt 2
                echo "Usage: npresleep add <note-path>"
                return 1
            end
            _npresleep_add $argv[2..-1]

        case clear
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

    if not test -f "$note_path"
        if test -f "$NOTES_DIR/$note_path"
            set note_path "$NOTES_DIR/$note_path"
        else
            echo "Note not found: $note_path"
            return 1
        end
    end

    # WHY: resolve to absolute path — relative paths like "journal/2026-03-13.md" and
    # "$NOTES_DIR/journal/2026-03-13.md" are the same file but grep -qxF treats them
    # as different, creating duplicate queue entries (Sweep audit)
    set -l resolved (realpath "$note_path" 2>/dev/null; or echo "$note_path")
    set note_path "$resolved"

    # WHY: grep -qxF for exact full-line match, not substring
    # -qF alone would match "/path/to/foo.md" against "/path/to/foobar.md" (ChatGPT audit)
    if test -f "$queue_file"
        if grep -qxF "$note_path" "$queue_file"
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
    # WHY: filter blank lines to prevent ghost entries (Claude audit)
    while read -l line
        if test -z "$line"
            continue
        end
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

    # WHY: read notes into array line-by-line — using `while read` instead of
    # command substitution to properly handle paths with special characters.
    # Filter blank lines to prevent ghost entries (Claude audit + Sweep audit)
    set -l notes
    while read -l line
        if test -n "$line"
            set notes $notes "$line"
        end
    end <"$queue_file"
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

    set -l reviewed 0
    for f in $notes
        if not test -f "$f"
            echo "  Skipping (file not found): $f"
            continue
        end

        set -l rel (string replace "$NOTES_DIR/" "" "$f")
        echo ""
        echo "--- Reviewing: $rel ---"
        $EDITOR "$f"
        set reviewed (math $reviewed + 1)

        echo ""
        echo "  Say to yourself: \"I will be tested on this tomorrow.\""
        read -P "  [Enter for next note] " -l _
    end

    echo ""
    echo "=== PRE-SLEEP REVIEW COMPLETE ==="
    echo "  $reviewed / $total note(s) reviewed."

    # WHY: only clear the queue if ALL notes were reviewed
    # if user Ctrl+C'd or skipped, preserve the queue for retry (Kimi audit)
    if test $reviewed -eq $total
        echo "  Sleep will consolidate these. Morning recall will test them."
        rm "$queue_file"
    else
        echo ""
        echo "  Session incomplete. Queue preserved — run npresleep again to resume."
    end
end
