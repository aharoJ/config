# path: ~/.config/fish/internal/notes/infrastructure/nsync.fish
# description: Git sync for notes. Pulls with rebase first to avoid merge conflicts,
#              then stages all changes, commits with timestamp, and pushes.
#              Auto-installs a pre-commit hook that blocks secrets on first run.
# date: 2026-02-26
function nsync --description "notes: git sync (pull → commit → push)"
    __notes_require; or return 1

    if not test -d "$NOTES_DIR/.git"
        echo "Error: $NOTES_DIR is not a git repository."
        echo "Initialize: cd \"$NOTES_DIR\" && git init"
        return 1
    end

    cd "$NOTES_DIR"; or return 1

    # WHY: install pre-commit hook if missing — prevents secrets from ever
    # entering history. Reactive auditing is too late; preventive hooks are better.
    set -l hook "$NOTES_DIR/.git/hooks/pre-commit"
    if not test -f "$hook"
        echo "Installing pre-commit hook (secret detection)..."
        echo '#!/bin/sh' >"$hook"
        echo '# Auto-installed by nsync — blocks commits containing secrets' >>"$hook"
        echo 'if git diff --cached --diff-filter=ACM -z --name-only | xargs -0 grep -lP "(?i)(api[_-]?key|secret|password|token|aws_access_key_id|AKIA[A-Z0-9]{16})" 2>/dev/null; then' >>"$hook"
        echo '    echo "BLOCKED: potential secret detected in staged files."' >>"$hook"
        echo '    echo "Review with: git diff --cached"' >>"$hook"
        echo '    exit 1' >>"$hook"
        echo 'fi' >>"$hook"
        chmod +x "$hook"
    end

    # WHY: pull with rebase first — your local commits replay on top of remote,
    # avoiding merge commits that clutter notes history
    echo "Pulling..."
    git pull --rebase --quiet 2>/dev/null
    # WHY: pull failure is non-fatal — could be first push or offline
    # we continue to commit and push regardless

    # WHY: stage everything — notes are not code, there's no reason to
    # selectively stage. If it's in NOTES_DIR, it belongs in the repo.
    git add -A

    # WHY: check if there's actually anything to commit
    if git diff --cached --quiet
        echo "Nothing to commit. Already in sync."
        return 0
    end

    set -l msg "sync: "(date +%Y-%m-%d\ %H:%M)
    git commit -m "$msg" --quiet

    echo "Pushing..."
    if git push --quiet 2>/dev/null
        echo "Synced: $msg"
    else
        echo "Committed locally: $msg"
        echo "Push failed — you may be offline. Run nsync again later."
    end
end
