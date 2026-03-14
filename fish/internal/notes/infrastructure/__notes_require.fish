# path: ~/.config/fish/internal/notes/infrastructure/__notes_require.fish
# description: Guard function. Validates NOTES_DIR exists before any note function runs.
#              Every note function calls this first. If it fails, nothing touches the filesystem.
# date: 2026-02-26
function __notes_require
    # WHY: check both that the variable is set AND non-empty
    # a variable can be set but empty, which would pass `set -q` but fail on `-d`
    if not set -q NOTES_DIR
        echo "Error: NOTES_DIR is not set."
        echo "Add to config.fish: set -gx NOTES_DIR \"\$HOME/notes\""
        return 1
    end

    if test -z "$NOTES_DIR"
        echo "Error: NOTES_DIR is empty."
        echo "Add to config.fish: set -gx NOTES_DIR \"\$HOME/notes\""
        return 1
    end

    if not test -d "$NOTES_DIR"
        echo "Error: NOTES_DIR does not exist: $NOTES_DIR"
        echo "Create it: mkdir -p \"$NOTES_DIR\""
        return 1
    end

    # WHY: check write permission — a read-only NOTES_DIR passes -d but
    # all note functions will fail with cryptic write errors (Sweep audit)
    if not test -w "$NOTES_DIR"
        echo "Error: NOTES_DIR is not writable: $NOTES_DIR"
        return 1
    end

    return 0
end
