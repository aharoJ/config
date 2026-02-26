# path: ~/.config/fish/internal/notes/nrate.fish
# description: Rate recall quality and compute adaptive review schedule (SM-2 inspired).
#              With no arguments, shows all notes due for review today (absorbed from ndue).
#              With a file argument, rates recall and updates the next review date.
# science: Wozniak SM-2 algorithm for adaptive spacing,
#          Cepeda et al. (2008) optimal spacing intervals depend on retention interval,
#          Cepeda et al. (2006) meta-analysis of 254 studies on distributed practice
# absorbed: ndue.fish (due queue display — output side of the same scheduling system)
# date: 2026-02-26
function nrate --description "notes: rate recall quality + show due queue"
    __notes_require; or return 1

    # WHY: zero-arg mode shows what's due. nrate IS the scheduling system —
    # both the input (rating) and output (due queue) belong in one function.
    if test (count $argv) -eq 0
        _nrate_show_due
        return $status
    end

    # Subcommand routing
    switch $argv[1]
        case due
            # WHY: explicit subcommand for due queue (alternative to zero-arg)
            _nrate_show_due
            return $status
        case '*'
            # Default: treat argument as a file to rate
            _nrate_file $argv
            return $status
    end
end

# --- internal: show due queue ---
function _nrate_show_due
    set -l today (date +%Y-%m-%d)
    set -l due_files
    set -l overdue_files

    # WHY: scan all .md files for next_review frontmatter
    # only files with next_review <= today are due
    for f in (find "$NOTES_DIR" -name '*.md' -not -path '*/.git/*' -not -path '*/secret/*')
        # WHY: grep for YAML frontmatter field, not arbitrary content
        set -l review_date (grep -m 1 '^next_review:' "$f" 2>/dev/null | sed 's/next_review: *//')
        if test -z "$review_date"
            continue
        end

        # WHY: string comparison works for ISO dates (YYYY-MM-DD)
        if test "$review_date" = "$today"
            set due_files $due_files "$f"
        else if test "$review_date" \< "$today"
            set overdue_files $overdue_files "$f"
        end
    end

    set -l total (math (count $due_files) + (count $overdue_files))

    if test $total -eq 0
        echo "No notes due for review. You're caught up."
        return 0
    end

    echo "=== REVIEW QUEUE ($today) ==="
    echo ""

    if test (count $overdue_files) -gt 0
        echo "  OVERDUE: "(count $overdue_files)" note(s)"
        echo ""
        for f in $overdue_files
            set -l review_date (grep -m 1 '^next_review:' "$f" | sed 's/next_review: *//')
            set -l rel (string replace "$NOTES_DIR/" "" "$f")
            echo "    ⚠  $rel (was due: $review_date)"
        end
        echo ""
    end

    if test (count $due_files) -gt 0
        echo "  DUE TODAY: "(count $due_files)" note(s)"
        echo ""
        for f in $due_files
            set -l rel (string replace "$NOTES_DIR/" "" "$f")
            echo "    →  $rel"
        end
        echo ""
    end

    echo "  Total: $total note(s) waiting for review."
    echo ""
    echo "  To review a note: nrate <path-to-note>"
    echo ""

    # WHY: fzf picker for quick selection if available
    if command -q fzf
        set -l all_due $overdue_files $due_files
        set -l display_names
        for f in $all_due
            set display_names $display_names (string replace "$NOTES_DIR/" "" "$f")
        end

        set -l chosen (printf '%s\n' $display_names | fzf --prompt="Pick a note to review > " --preview="bat --color=always --style=plain $NOTES_DIR/{}" 2>/dev/null)
        if test -n "$chosen"
            _nrate_file "$NOTES_DIR/$chosen"
        end
    end
end

# --- internal: rate a specific file ---
function _nrate_file
    set -l file $argv[1]

    # WHY: resolve relative paths against NOTES_DIR
    if not test -f "$file"
        if test -f "$NOTES_DIR/$file"
            set file "$NOTES_DIR/$file"
        else
            echo "File not found: $file"
            return 1
        end
    end

    set -l today (date +%Y-%m-%d)

    echo "=== RATE RECALL ==="
    echo ""
    echo "  File: "(string replace "$NOTES_DIR/" "" "$file")
    echo ""
    echo "  How well did you recall this material?"
    echo ""
    echo "    1) again  — total blank, need to relearn"
    echo "    2) hard   — recalled with significant effort/errors"
    echo "    3) good   — recalled with some effort"
    echo "    4) easy   — recalled instantly, no effort"
    echo ""

    read -P "  Rating [1-4]: " -l rating

    # WHY: map rating to interval multiplier (SM-2 inspired, simplified)
    # again=1 day, hard=3 days, good=7 days, easy=21 days
    # these are base intervals; real SM-2 uses easiness factor but
    # this is good enough for a terminal tool
    switch $rating
        case 1 again
            set -l next (date -v+1d +%Y-%m-%d 2>/dev/null; or date -d '+1 day' +%Y-%m-%d)
            set -l label "again"
        case 2 hard
            set -l next (date -v+3d +%Y-%m-%d 2>/dev/null; or date -d '+3 days' +%Y-%m-%d)
            set -l label "hard"
        case 3 good
            set -l next (date -v+7d +%Y-%m-%d 2>/dev/null; or date -d '+7 days' +%Y-%m-%d)
            set -l label "good"
        case 4 easy
            set -l next (date -v+21d +%Y-%m-%d 2>/dev/null; or date -d '+21 days' +%Y-%m-%d)
            set -l label "easy"
        case '*'
            echo "Invalid rating. Use 1-4."
            return 1
    end

    # WHY: compute next date using macOS date (-v) with GNU fallback (-d)
    # these are set inside the switch cases above but Fish scoping
    # requires us to handle this carefully
    set -l days_map 1 3 7 21
    set -l label_map again hard good easy

    if not string match -qr '^[1-4]$' "$rating"
        echo "Invalid rating. Use 1-4."
        return 1
    end

    set -l days $days_map[$rating]
    set -l label $label_map[$rating]

    # WHY: macOS uses -v+Nd, GNU/Linux uses -d '+N days'
    set -l next (date -v+"$days"d +%Y-%m-%d 2>/dev/null)
    if test $status -ne 0
        set next (date -d "+$days days" +%Y-%m-%d)
    end

    # WHY: update or insert frontmatter fields
    # we use sed to replace existing fields or append if missing
    if grep -q '^next_review:' "$file"
        sed -i'' "s/^next_review:.*/next_review: $next/" "$file"
    else if grep -q '^---$' "$file"
        # WHY: insert after first --- frontmatter delimiter
        sed -i'' "0,/^---$/s/^---$/---\nnext_review: $next/" "$file"
    else
        # WHY: no frontmatter exists, prepend it
        set -l tmp (mktemp)
        echo "---" >"$tmp"
        echo "next_review: $next" >>"$tmp"
        echo "last_rated: $today" >>"$tmp"
        echo "last_rating: $label" >>"$tmp"
        echo "---" >>"$tmp"
        cat "$file" >>"$tmp"
        mv "$tmp" "$file"
    end

    # WHY: also update last_rated and last_rating for history
    if grep -q '^last_rated:' "$file"
        sed -i'' "s/^last_rated:.*/last_rated: $today/" "$file"
    end
    if grep -q '^last_rating:' "$file"
        sed -i'' "s/^last_rating:.*/last_rating: $label/" "$file"
    end

    echo ""
    echo "  Rated: $label"
    echo "  Next review: $next"
end
