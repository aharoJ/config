# path: ~/.config/fish/internal/notes/schedule/nrate.fish
# description: Rate recall quality and compute adaptive review schedule (SM-2 inspired).
#              With no arguments, shows all notes due for review today (absorbed from ndue).
#              With a file argument, rates recall and updates the next review date.
# science: Wozniak SM-2 algorithm for adaptive spacing,
#          Cepeda et al. (2008) optimal spacing intervals depend on retention interval,
#          Cepeda et al. (2006) meta-analysis of 254 studies on distributed practice
# absorbed: ndue.fish (due queue display — output side of the same scheduling system)
# patched: 2026-02-26
#   - fix: proper YAML frontmatter parsing — only reads/writes the top-of-file block
#     between first and second `---`, not body content (ChatGPT audit)
#   - fix: inserts missing last_rated/last_rating on first rating (Claude + ChatGPT audit)
#   - fix: no more sed 0,/pattern/ (GNU-only, fails on macOS BSD) (Claude + DeepSeek audit)
#   - fix: fzf preview quotes {} for filenames with spaces (ChatGPT audit)
#   - fix: frontmatter reader now anchored to NR==1 — if file doesn't start with ---,
#     body --- separators were treated as frontmatter boundaries (ChatGPT second-pass audit)
#   - fix: awk scripts strip \r for CRLF robustness (Kimi second-pass audit)
# date: 2026-02-26
function nrate --description "notes: rate recall quality + show due queue"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        _nrate_show_due
        return $status
    end

    switch $argv[1]
        case due
            _nrate_show_due
            return $status
        case '*'
            _nrate_file $argv
            return $status
    end
end

# --- helper: extract a frontmatter field value from a file ---
# WHY: only reads the YAML block IF and ONLY IF line 1 is exactly `---`.
# Previous version used a block counter that would match ANY `---` in the file,
# treating body markdown separators as frontmatter boundaries (ChatGPT second-pass audit).
# Also strips \r for CRLF robustness (Kimi audit).
function _nrate_get_frontmatter_field
    set -l file $argv[1]
    set -l field $argv[2]

    # WHY: guard against nonexistent files — awk errors are cryptic (Sweep audit)
    if not test -f "$file"
        return 1
    end

    awk -v field="$field" '
        { gsub(/\r$/, "") }
        NR == 1 {
            if ($0 != "---") exit
            next
        }
        /^---$/ { exit }
        $0 ~ ("^" field ":[[:space:]]*") {
            sub("^" field ":[[:space:]]*", "")
            print
            exit
        }
    ' "$file"
end

# --- helper: write/update frontmatter fields in a file ---
# WHY: uses awk + temp file approach — fully portable across BSD and GNU.
# no sed -i quirks, no 0,/pattern/ GNU-isms. (Claude + DeepSeek audit)
# WHY: strips \r for CRLF robustness (Kimi audit)
function _nrate_set_frontmatter
    set -l file $argv[1]
    set -l next_review $argv[2]
    set -l last_rated $argv[3]
    set -l last_rating $argv[4]

    set -l tmp (mktemp)

    # WHY: check if file already has YAML frontmatter (starts with ---)
    # strip \r before comparing — CRLF files would fail this check (Kimi audit)
    set -l first_line (head -1 "$file" | string replace -r '\r$' '')

    if test "$first_line" = "---"
        # WHY: file has frontmatter — update existing fields or insert new ones
        # awk approach: read the frontmatter block, update/insert fields, pass body through
        awk -v nr="$next_review" -v lr="$last_rated" -v lg="$last_rating" '
        BEGIN { in_fm = 0; fm_end = 0; did_nr = 0; did_lr = 0; did_lg = 0 }
        { gsub(/\r$/, "") }
        NR == 1 && /^---$/ { in_fm = 1; print; next }
        in_fm && /^---$/ {
            # end of frontmatter — insert any missing fields before closing ---
            if (!did_nr) print "next_review: " nr
            if (!did_lr) print "last_rated: " lr
            if (!did_lg) print "last_rating: " lg
            print "---"
            in_fm = 0; fm_end = 1; next
        }
        in_fm && /^next_review:/ { print "next_review: " nr; did_nr = 1; next }
        in_fm && /^last_rated:/ { print "last_rated: " lr; did_lr = 1; next }
        in_fm && /^last_rating:/ { print "last_rating: " lg; did_lg = 1; next }
        { print }
        ' "$file" >"$tmp"
    else
        # WHY: no frontmatter exists — prepend a new block
        echo "---" >"$tmp"
        echo "next_review: $next_review" >>"$tmp"
        echo "last_rated: $last_rated" >>"$tmp"
        echo "last_rating: $last_rating" >>"$tmp"
        echo "---" >>"$tmp"
        cat "$file" >>"$tmp"
    end

    # WHY: verify tmp file has content before replacing — if awk fails silently,
    # an empty tmp file would destroy the note (Sweep audit)
    if test -s "$tmp"
        mv "$tmp" "$file"
    else
        echo "Error: frontmatter update failed — original file preserved." >&2
        rm -f "$tmp"
        return 1
    end
end

# --- internal: show due queue ---
function _nrate_show_due
    set -l today (date +%Y-%m-%d)
    set -l due_files
    set -l overdue_files

    # WHY: scan all .md files for next_review in YAML frontmatter only
    for f in (find "$NOTES_DIR" -type f -name '*.md' -not -path '*/.git/*' -not -path '*/secret/*')
        set -l review_date (_nrate_get_frontmatter_field "$f" "next_review")
        if test -z "$review_date"
            continue
        end

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
            set -l review_date (_nrate_get_frontmatter_field "$f" "next_review")
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
    # WHY: quote {} in preview for filenames with spaces (ChatGPT audit)
    if command -q fzf
        set -l all_due $overdue_files $due_files
        set -l display_names
        for f in $all_due
            set display_names $display_names (string replace "$NOTES_DIR/" "" "$f")
        end

        set -l preview_cmd "cat '$NOTES_DIR/{}'"
        if command -q bat
            set preview_cmd "bat --color=always --style=plain '$NOTES_DIR/{}'"
        end

        set -l chosen (printf '%s\n' $display_names | fzf --prompt="Pick a note to review > " --preview="$preview_cmd" 2>/dev/null)
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

    set -l days_map 1 3 7 21
    set -l label_map again hard good easy

    if not string match -qr '^[1-4]$' "$rating"
        echo "Invalid rating. Use 1-4."
        return 1
    end

    set -l days $days_map[$rating]
    set -l label $label_map[$rating]

    # WHY: cross-platform date arithmetic
    set -l next (date -v+"$days"d +%Y-%m-%d 2>/dev/null)
    if test $status -ne 0
        set next (date -d "+$days days" +%Y-%m-%d)
    end

    # WHY: use the proper frontmatter helper — handles all cases:
    # no frontmatter, existing frontmatter with/without fields (Claude + ChatGPT audit)
    _nrate_set_frontmatter "$file" "$next" "$today" "$label"

    echo ""
    echo "  Rated: $label"
    echo "  Next review: $next"
end
