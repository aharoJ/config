# path: ~/.config/fish/internal/notes/_notes_require.fish
# description: Guard helper. Ensures NOTES_DIR exists before any notes function runs.
# credit: ChatGPT suggestion, good engineering practice
# date: 2026-02-24
function __notes_require --description "notes: ensure NOTES_DIR exists"
    if test -z "$NOTES_DIR"
        echo "ERROR: NOTES_DIR is not set. Add to config.fish:"
        echo "  set -gx NOTES_DIR ~/notes"
        return 1
    end
    if not test -d "$NOTES_DIR"
        echo "ERROR: NOTES_DIR does not exist: $NOTES_DIR"
        echo "Create it with: mkdir -p $NOTES_DIR"
        return 1
    end
end
