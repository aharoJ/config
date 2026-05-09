function rp-wt --description 'Create a review-protocol git worktree with CC settings copy'
    set -l usage 'usage: rp-wt new <branch> [base] | rp-wt co <branch>'

    if test (count $argv) -lt 2
        echo $usage >&2
        return 2
    end

    set -l verb $argv[1]
    set -l branch $argv[2]
    set -l main "$HOME/.skills/review-protocol"

    if string match -q -- '-*' $branch
        echo "branch name must not start with '-': $branch" >&2
        return 2
    end

    set -l safe_branch (string replace -ra '[^A-Za-z0-9._-]' '-' -- $branch)
    set -l wt "$HOME/.skills/review-protocol-$safe_branch"

    if test -e "$wt"
        echo "path already exists: $wt" >&2
        return 1
    end

    switch $verb
        case new
            set -l base $argv[3]
            test -n "$base"; or set base main
            if string match -q -- '-*' $base
                echo "base ref must not start with '-': $base" >&2
                return 2
            end
            git -C $main worktree add -b $branch $wt $base >&2; or return $status
        case co
            git -C $main worktree add $wt $branch >&2; or return $status
        case '*'
            echo $usage >&2
            return 2
    end

    if test -f "$main/.claude/settings.local.json"
        mkdir -p "$wt/.claude"; or echo "warn: mkdir $wt/.claude failed" >&2
        if not test -e "$wt/.claude/settings.local.json"
            cp "$main/.claude/settings.local.json" "$wt/.claude/settings.local.json"; or echo "warn: settings.local.json copy failed" >&2
        end
    end

    echo $wt
end
