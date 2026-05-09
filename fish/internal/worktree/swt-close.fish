function swt-close --description 'Cap commit + notes commit, then print teardown instructions'
    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo 'swt-close: not inside a git repository' >&2
        return 1
    end

    set -l repo_bases "$HOME/.repository" "$HOME/.westernu" "$HOME/.skills"

    set -l matched false
    for base in $repo_bases
        if string match -q "$base/*" -- $toplevel
            set matched true
            break
        end
    end

    if test "$matched" = false
        echo "swt-close: cwd ($toplevel) is not under a known repo base (~/.repository/, ~/.westernu/, or ~/.skills/)" >&2
        return 1
    end

    set -l main_wt (git -C $toplevel worktree list --porcelain 2>/dev/null | head -1 | string replace 'worktree ' '')
    if test -z "$main_wt"
        echo 'swt-close: could not determine main worktree' >&2
        return 1
    end

    if test "$toplevel" = "$main_wt"
        echo "swt-close: cwd ($toplevel) is the main worktree, not a branch worktree" >&2
        return 1
    end

    set -l main_branch (git -C $main_wt rev-parse --abbrev-ref HEAD 2>/dev/null)
    if test -z "$main_branch" -o "$main_branch" = HEAD
        echo 'swt-close: main worktree has detached HEAD — cannot determine push branch' >&2
        return 1
    end

    set -l branch (git -C $toplevel rev-parse --abbrev-ref HEAD 2>/dev/null)
    if test -z "$branch" -o "$branch" = HEAD
        echo 'swt-close: HEAD is detached — cannot determine branch name' >&2
        return 1
    end

    echo "swt-close: staging all worktree changes..." >&2
    git -C $toplevel add -A >&2
    if test $status -ne 0
        echo 'swt-close: staging FAILED — aborting. Resolve the issue and retry.' >&2
        return 1
    end

    echo "swt-close: creating cap commit (--allow-empty)..." >&2
    git -C $toplevel commit --allow-empty -m "swt-close: cap commit on $branch" >&2
    if test $status -ne 0
        echo 'swt-close: cap commit FAILED — aborting. Resolve the issue and retry.' >&2
        return 1
    end

    set -l cap_hash (git -C $toplevel log -1 --format='%H' 2>/dev/null)
    if test -z "$cap_hash"
        echo 'swt-close: cap commit verification FAILED — git log returned empty hash' >&2
        return 1
    end
    echo "swt-close: cap commit verified: $cap_hash" >&2

    set -l notes_dir "$HOME/.notes"
    echo "swt-close: committing notes..." >&2
    git -C $notes_dir add -A >&2
    if test $status -ne 0
        echo 'swt-close: notes staging FAILED — cap commit exists but notes are unstaged. Resolve and retry.' >&2
        return 1
    end
    git -C $notes_dir commit --allow-empty -m "project: swt-close notes for $branch" >&2
    if test $status -ne 0
        echo 'swt-close: notes commit FAILED — cap commit exists but notes are uncommitted. Resolve and retry.' >&2
        return 1
    end

    set -l notes_hash (git -C $notes_dir log -1 --format='%H' 2>/dev/null)
    if test -z "$notes_hash"
        echo 'swt-close: notes commit verification FAILED — git log returned empty hash' >&2
        return 1
    end
    echo "swt-close: notes commit verified: $notes_hash" >&2

    set -l q_main_wt (string replace -a "'" "'\\''" -- $main_wt)
    set -l q_branch (string replace -a "'" "'\\''" -- $branch)
    set -l q_toplevel (string replace -a "'" "'\\''" -- $toplevel)
    set -l q_main_branch (string replace -a "'" "'\\''" -- $main_branch)

    echo ""
    echo "── teardown (run manually) ──"
    echo "git -C '$q_main_wt' merge --ff-only '$q_branch'"
    echo "git -C '$q_main_wt' push origin '$q_main_branch'"
    echo "git -C '$q_main_wt' worktree remove '$q_toplevel'"
    echo "git -C '$q_main_wt' branch -d '$q_branch'"
end
