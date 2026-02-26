# path: ~/.config/fish/internal/notes/nerror.fish
# description: Error notebook (错题本 cuòtí běn). Log mistakes with trigger patterns
#              and prevention protocols. Includes pattern analysis to surface recurring
#              error types across all logged errors.
# science: Metcalfe (2017) learning from errors enhances memory (especially high-confidence errors),
#          Bjork (1994) desirable difficulties — errors + correction = stronger encoding,
#          East Asian cuòtí tradition — systematic error tracking as core study method
# absorbed: nerror_patterns.fish (recurring pattern analysis — same error-tracking system)
# date: 2026-02-26
function nerror --description "notes: error notebook + pattern analysis"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage:"
        echo "  nerror <topic>           Log a new error"
        echo "  nerror list              Show all logged errors"
        echo "  nerror patterns          Analyze recurring error types"
        echo ""
        echo "Track mistakes → identify triggers → build prevention protocols."
        return 1
    end

    set -l cmd $argv[1]
    set -l dir "$NOTES_DIR/learning/errors"
    mkdir -p "$dir"

    switch $cmd
        case list
            _nerror_list
        case patterns
            _nerror_patterns
        case '*'
            # WHY: anything that isn't a subcommand is treated as a topic
            _nerror_log $argv
    end
end

# --- internal: log a new error ---
function _nerror_log
    set -l topic (string join ' ' $argv)
    set -l slug (string replace -a ' ' '-' (string lower "$topic"))
    set -l day (date +%Y-%m-%d)
    set -l time_stamp (date +%H:%M)
    set -l file "$NOTES_DIR/learning/errors/$day-$slug.md"

    if not test -f "$file"
        echo "# Error: $topic" >"$file"
        echo "" >>"$file"
        echo "_Date: $day at $time_stamp_" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## What I did (the mistake)" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## Why it was wrong" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## The correct model" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## Error type" >>"$file"
        echo "<!-- Tag with a category so patterns can surface recurring types. -->" >>"$file"
        echo "<!-- Examples: off-by-one, null-handling, async-timing, scope-confusion, -->" >>"$file"
        echo "<!-- wrong-abstraction, premature-optimization, missed-edge-case -->" >>"$file"
        echo "" >>"$file"
        echo "type: " >>"$file"
        echo "" >>"$file"
        echo "## Trigger pattern — how to SPOT this mistake next time" >>"$file"
        echo "<!-- What should I notice that would warn me I'm about to make this error? -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## Prevention protocol" >>"$file"
        echo "<!-- What specific action prevents this class of error? -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## Confidence at time of error: [high/medium/low]" >>"$file"
        echo "<!-- High-confidence errors are the most valuable to study (Metcalfe 2017) -->" >>"$file"
        echo "" >>"$file"
    end

    echo "=== ERROR NOTEBOOK ==="
    echo ""
    echo "  Topic: $topic"
    echo ""
    echo "  1. Describe the mistake."
    echo "  2. Explain WHY it was wrong."
    echo "  3. Write the correct model."
    echo "  4. Tag the error TYPE (for pattern detection)."
    echo "  5. Define the TRIGGER — what to notice next time."
    echo "  6. Write a PREVENTION protocol."
    echo ""
    echo "  High-confidence errors (you were SURE you were right)"
    echo "  are the most valuable to study."
    echo ""

    cd "$NOTES_DIR"; and $EDITOR "$file"
end

# --- internal: list all logged errors ---
function _nerror_list
    set -l dir "$NOTES_DIR/learning/errors"
    set -l count (find "$dir" -name '*.md' 2>/dev/null | wc -l | string trim)

    if test "$count" -eq 0
        echo "No errors logged yet."
        return 0
    end

    echo "=== ERROR LOG ($count errors) ==="
    echo ""

    # WHY: reverse chronological — most recent errors first
    for f in (find "$dir" -name '*.md' | sort -r)
        set -l name (basename "$f" .md)
        set -l error_type (grep -m 1 '^type: ' "$f" 2>/dev/null | sed 's/type: *//')
        if test -n "$error_type"
            echo "  $name  [$error_type]"
        else
            echo "  $name"
        end
    end
    echo ""

    # WHY: fzf for quick navigation if available
    if command -q fzf
        set -l chosen (find "$dir" -name '*.md' | sort -r | while read -l f
            set -l name (basename "$f" .md)
            echo "$name"
        end | fzf --prompt="Open error > " --preview="bat --color=always --style=plain $dir/{}.md" 2>/dev/null)

        if test -n "$chosen"
            $EDITOR "$dir/$chosen.md"
        end
    end
end

# --- internal: analyze recurring error patterns ---
# WHY: absorbed from nerror_patterns.fish — this IS error tracking,
# not a separate concern. Pattern analysis is the payoff of logging errors.
function _nerror_patterns
    set -l dir "$NOTES_DIR/learning/errors"
    set -l count (find "$dir" -name '*.md' 2>/dev/null | wc -l | string trim)

    if test "$count" -eq 0
        echo "No errors logged yet. Log some first: nerror <topic>"
        return 0
    end

    echo "=== ERROR PATTERN ANALYSIS ==="
    echo ""

    # WHY: extract all error types and count occurrences
    # this surfaces your SYSTEMIC weaknesses, not just individual mistakes
    set -l types
    for f in (find "$dir" -name '*.md')
        set -l t (grep -m 1 '^type: ' "$f" 2>/dev/null | sed 's/type: *//' | string trim)
        if test -n "$t"
            set types $types "$t"
        end
    end

    if test (count $types) -eq 0
        echo "  No error types tagged yet."
        echo "  Add 'type: <category>' to your error notes for pattern detection."
        return 0
    end

    # WHY: sort and count — most frequent error types first
    echo "  Error type frequency:"
    echo ""
    printf '%s\n' $types | sort | uniq -c | sort -rn | while read -l line
        set -l num (echo $line | awk '{print $1}')
        set -l type (echo $line | awk '{$1=""; print $0}' | string trim)
        echo "    $num × $type"
    end
    echo ""

    # WHY: show most recent error per type for quick context
    echo "  Most recent per type:"
    echo ""
    set -l unique_types (printf '%s\n' $types | sort -u)
    for t in $unique_types
        set -l latest (grep -rl "^type: $t" "$dir" 2>/dev/null | sort -r | head -1)
        if test -n "$latest"
            echo "    [$t] → "(basename "$latest" .md)
        end
    end
    echo ""

    echo "  Total errors logged: $count"
    echo "  Types tagged: "(count $types)" / $count"

    # WHY: flag untagged errors — they're invisible to pattern analysis
    set -l untagged (math "$count - (count $types)")
    if test $untagged -gt 0
        echo ""
        echo "  ⚠  $untagged error(s) have no 'type:' tag — they won't appear in patterns."
    end
end
