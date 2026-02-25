# path: ~/.config/fish/internal/notes/nenv.fish
# description: Set NOTES_DIR environment variable if not already set. Create directory structure.
# date: 2026-02-24
function nenv --description "notes: ensure NOTES_DIR is set and directory exists"
    if not set -q NOTES_DIR
        set -gx NOTES_DIR "$HOME/notes"
        echo "NOTES_DIR set to: $NOTES_DIR"
    else
        echo "NOTES_DIR is: $NOTES_DIR"
    end

    if not test -d "$NOTES_DIR"
        echo "Creating directory structure..."
        mkdir -p "$NOTES_DIR"/{journal/reviews,learning/{til,feynman,interrogations,diagrams,memorize,drills,errors,recall,calibration,struggles,embodied,collapses,teach,cornell},projects,templates,secret}
        echo "Done."
    else
        echo "Directory exists."
    end
end
