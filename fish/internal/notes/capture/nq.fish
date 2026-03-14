# path: ~/.config/fish/internal/notes/capture/nq.fish
# description: Append a timestamped one-liner to today's journal. No editor opens.
#              For capturing thoughts mid-flow without context-switching.
#              Distinct from note (which opens $EDITOR — higher friction, deeper capture).
# patched: 2026-02-26
#   - fix: uses shared _notes_ensure_journal to eliminate template duplication (Claude audit)
#   - fix: sanitize newlines/carriage returns from argv (Kimi audit)
#   - fix: regex-based sanitization — single-quoted '\n' is literal backslash-n,
#     not a newline character. Use -ra regex mode (ChatGPT + Kimi second-pass audit)
# date: 2026-02-26
function nq --description "notes: quick append to journal (no editor)"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nq <thought>"
        echo ""
        echo "Appends a timestamped line to today's journal."
        echo "No editor opens. Back to work in <1 second."
        return 1
    end

    # WHY: shared helper ensures template exists and returns the path
    # WHY: check both exit status AND non-empty result — if journal creation fails,
    # $file would be empty and we'd append to nothing (Sweep audit)
    set -l file (_notes_ensure_journal)
    if test $status -ne 0 -o -z "$file"
        return 1
    end
    set -l time_stamp (date +%H:%M)

    # WHY: sanitize newlines and carriage returns from input
    # must use -ra (regex mode) — in non-regex mode, '\n' matches the literal
    # two-character string backslash-n, NOT an actual newline (Kimi + ChatGPT audit)
    set -l entry (string join ' ' $argv | string replace -ra '[\r\n]+' ' ' | string trim)

    # WHY: guard against empty entry after sanitization — input that was only
    # newlines/whitespace would produce a blank journal line (Sweep audit)
    if test -z "$entry"
        echo "Error: entry is empty after sanitization."
        return 1
    end

    # WHY: append with timestamp — the journal becomes a timestamped log
    echo "- $time_stamp — $entry" >>"$file"

    echo "  [$time_stamp] → "(basename "$file")
end
