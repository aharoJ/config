# path: ~/.config/fish/internal/notes/infrastructure/nsync.fish
# description: Git sync for notes. Pulls with rebase first to avoid merge conflicts,
#              then stages all changes, commits with timestamp, and pushes.
#              Auto-installs a pre-commit hook that blocks secrets on first run.
# patched: 2026-02-26
#   - fix: pre-commit hook uses grep -E not -P (all 4 audits — -P absent on macOS BSD)
#   - fix: git pull --rebase now fails fast on conflicts (ChatGPT + DeepSeek audit)
#   - fix: stderr no longer silenced on pull (DeepSeek audit)
#   - fix: git commit exit code now checked — pre-commit hook rejection was a silent
#     false-success path that continued to push (ChatGPT second-pass audit)
#   - fix: git push stderr no longer silenced — auth errors and remote rejections
#     were being mislabeled as "maybe offline" (ChatGPT second-pass audit)
#   - fix: secret hook regex tightened — bare words like "token", "secret", "password"
#     false-positive on programming notes. Now requires assignment context (:= or key shape)
#     (ChatGPT second-pass audit)
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
        # WHY: grep -E (extended regex) instead of -P (Perl regex)
        # macOS BSD grep does not support -P (all 4 audits flagged this)
        #
        # WHY: assignment-context patterns instead of bare words
        # bare "token", "secret", "password" false-positive constantly on programming
        # notes about OAuth, password hashing, etc. (ChatGPT second-pass audit)
        # patterns matched:
        #   api_key = "..."  /  api-key: ...  /  apikey=...
        #   password: ...  /  password=...
        #   secret: ...  /  secret=...
        #   token: ...  /  token=...
        #   aws_access_key_id (any context — this is never in normal prose)
        #   AKIA[16 alphanums] (AWS access key shape)
        #   -----BEGIN.*PRIVATE KEY----- (PEM private keys)
        echo 'if git diff --cached --diff-filter=ACM -z --name-only | xargs -0 grep -lEi "(api[_-]?key\s*[=:]|password\s*[=:]|secret\s*[=:]|token\s*[=:]|aws_access_key_id|AKIA[A-Z0-9]{16}|-----BEGIN.*PRIVATE KEY-----)" 2>/dev/null; then' >>"$hook"
        echo '    echo "BLOCKED: potential secret detected in staged files."' >>"$hook"
        echo '    echo "Review with: git diff --cached"' >>"$hook"
        echo '    exit 1' >>"$hook"
        echo 'fi' >>"$hook"
        chmod +x "$hook"
    end

    # WHY: pull with rebase first — your local commits replay on top of remote,
    # avoiding merge commits that clutter notes history
    # WHY: DO NOT silence stderr — if conflicts occur, the user must see them
    # (ChatGPT + DeepSeek: hiding errors meant conflicts went unnoticed)
    echo "Pulling..."
    if not git pull --rebase --quiet
        # WHY: fail fast on rebase conflicts — continuing would stage/commit
        # in a dirty rebase state, corrupting history (ChatGPT audit)
        echo ""
        echo "Pull failed — likely a rebase conflict."
        echo "Resolve manually:"
        echo "  cd \"$NOTES_DIR\""
        echo "  git status"
        echo "  # fix conflicts, then: git rebase --continue"
        echo "  # or abort: git rebase --abort"
        return 1
    end

    # WHY: stage everything — notes are not code, there's no reason to
    # selectively stage. If it's in NOTES_DIR, it belongs in the repo.
    git add -A

    # WHY: check if there's actually anything to commit
    if git diff --cached --quiet
        echo "Nothing to commit. Already in sync."
        return 0
    end

    set -l msg "sync: "(date +%Y-%m-%d\ %H:%M)

    # WHY: check commit exit code — if pre-commit hook blocks the commit,
    # or git config is broken, we must NOT continue to push. The old code
    # fell through to push and printed "Synced" on a failed commit (ChatGPT audit)
    if not git commit -m "$msg" --quiet
        echo ""
        echo "Commit failed — the pre-commit hook may have blocked it."
        echo "Review with: git diff --cached"
        return 1
    end

    # WHY: do NOT silence push stderr — auth errors, remote rejections, and
    # force-push protections were being mislabeled as "maybe offline" (ChatGPT audit)
    echo "Pushing..."
    if git push --quiet
        echo "Synced: $msg"
    else
        echo "Committed locally: $msg"
        echo "Push failed — check remote access, then run nsync again."
    end
end
