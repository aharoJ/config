# path: ~/.config/fish/internal/notes/nsync.fish
# description: Sync notes: add, commit, push.
# date: 2026-02-24
function nsync --description "notes: sync to remote"
    cd "$NOTES_DIR"; or return 1

    # Auto-install hook if missing
    if not test -f .git/hooks/pre-commit; and test -f .pre-commit-hook
        cp .pre-commit-hook .git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit
        echo "Pre-commit hook installed."
    end

    # Pull first to avoid conflicts
    git pull --rebase --quiet 2>/dev/null; or begin
        echo "Pull/rebase failed. Resolve conflicts, then rerun nsync."
        return 1
    end

    if test -z (git status --porcelain)
        echo "Nothing to sync."
        return 0
    end

    set -l msg
    if test (count $argv) -ge 1
        set msg (string join " " $argv)
    else
        set msg "sync: "(date '+%Y-%m-%d %H:%M')" notes update"
    end

    git add -A
    git status --short
    git commit -m "$msg"
    git push
end
