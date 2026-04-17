function stage-wt-rm --description 'Remove a stage git worktree (preserves branch)'
    if test (count $argv) -lt 1
        echo 'usage: stage-wt-rm <absolute-path>' >&2
        return 2
    end
    if string match -q -- '-*' $argv[1]
        echo "path must not start with '-': $argv[1]" >&2
        return 2
    end
    set -l main "$HOME/.repository/stage"
    git -C $main worktree remove $argv[1]
end
