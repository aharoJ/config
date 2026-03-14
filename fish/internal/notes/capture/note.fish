# path: ~/.config/fish/internal/notes/capture/note.fish
# description: Open today's journal entry in $EDITOR. Creates the file from a template
#              if it doesn't exist yet. The journal is the primary daily capture surface.
# patched: 2026-02-26
#   - fix: uses shared _notes_ensure_journal to eliminate template duplication (Claude audit)
# date: 2026-02-26
function note --description "notes: open today's journal"
    __notes_require; or return 1

    # WHY: shared helper ensures template exists and returns the path
    # single source of truth — change the template in one place (Claude audit)
    # WHY: check return status — if journal dir creation fails, $file is empty
    # and $EDITOR would open with no target (Sweep audit)
    set -l file (_notes_ensure_journal)
    if test $status -ne 0 -o -z "$file"
        return 1
    end

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
