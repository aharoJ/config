# Git

A working reference for precise, professional version control.

---

## Inspecting History

```bash
git log --oneline                                    # compressed commit history
git log --oneline -- path/to/file                    # history of a single file
git log -p -- path/to/file                           # history with full diffs
git log --author="name" --since="2024-01-01"         # filtered by author and date
git log --graph --oneline --all                       # visual branch topology
```

## Reading Old Versions

```bash
git show abc1234:path/to/file                        # print file at a specific commit
git show HEAD~3:path/to/file                         # print file 3 commits ago
git diff abc1234 -- path/to/file                     # diff current vs old commit
git diff abc1234 def5678 -- path/to/file             # diff between two commits
```

## Restoring Files

```bash
git checkout abc1234 -- path/to/file                 # replace file with old version (stages it)
git checkout HEAD -- path/to/file                    # undo the above, restore to latest
git restore --source=abc1234 -- path/to/file         # modern equivalent of checkout
git restore --staged -- path/to/file                 # unstage without discarding changes
```

## Staging with Precision

```bash
git add -p                                           # stage hunks interactively
git add -p path/to/file                              # interactive staging on one file
git diff --cached                                    # review what is staged before committing
git reset HEAD -- path/to/file                       # unstage a file
```

## Committing

```bash
git commit -m "message"                              # standard commit
git commit --amend                                   # rewrite the last commit message or contents
git commit --amend --no-edit                          # add staged changes to last commit silently
```

## Branching

```bash
git branch                                           # list local branches
git branch -a                                        # list all branches including remote
git switch feature-branch                            # switch branches (modern)
git switch -c feature-branch                         # create and switch
git branch -d feature-branch                         # delete merged branch
git branch -D feature-branch                         # force delete unmerged branch
```

## Merging and Rebasing

```bash
git merge feature-branch                             # merge into current branch
git rebase main                                      # replay current branch on top of main
git rebase -i HEAD~4                                 # interactive rebase last 4 commits
```

Interactive rebase operations: `pick`, `reword`, `edit`, `squash`, `fixup`, `drop`.

## Stashing

```bash
git stash                                            # shelve uncommitted work
git stash list                                       # view all stashes
git stash pop                                        # apply most recent stash and remove it
git stash apply stash@{2}                            # apply a specific stash without removing
git stash drop stash@{0}                             # discard a specific stash
git stash -p                                         # stash specific hunks interactively
```

## Remote Operations

```bash
git remote -v                                        # list remotes
git fetch origin                                     # download remote changes without merging
git pull --rebase origin main                        # pull and rebase instead of merge commit
git push origin feature-branch                       # push branch to remote
git push --force-with-lease                          # safe force push (respects others' work)
```

## Undoing Work

```bash
git revert abc1234                                   # create a new commit that undoes a commit
git reset --soft HEAD~1                              # undo last commit, keep changes staged
git reset --mixed HEAD~1                             # undo last commit, keep changes unstaged
git reset --hard HEAD~1                              # undo last commit, discard everything
git clean -fd                                        # remove untracked files and directories
```

## Searching the Codebase

```bash
git grep "pattern"                                   # search tracked files
git grep "pattern" abc1234                           # search at a specific commit
git log -S "function_name"                           # find commits that added or removed a string
git log -G "regex"                                   # find commits matching a regex in diffs
git blame path/to/file                               # line-by-line authorship
```

## Cherry-Picking

```bash
git cherry-pick abc1234                              # apply a single commit to current branch
git cherry-pick abc1234 def5678                      # apply multiple commits in order
git cherry-pick --no-commit abc1234                  # apply changes without committing
```

## Tags

```bash
git tag v1.0.0                                       # lightweight tag
git tag -a v1.0.0 -m "release 1.0.0"                # annotated tag
git push origin v1.0.0                               # push a single tag
git push origin --tags                               # push all tags
```

## Configuration

```bash
git config --global user.name "Name"
git config --global user.email "email"
git config --global core.editor "nvim"
git config --global pull.rebase true                 # default pull to rebase
git config --global rerere.enabled true              # remember conflict resolutions
```

## Aliases Worth Having

```bash
git config --global alias.st "status -sb"
git config --global alias.lg "log --oneline --graph --all"
git config --global alias.last "log -1 HEAD --stat"
git config --global alias.unstage "reset HEAD --"
```

---

## Principles

Every commit should compile. Every message should explain why, not what. Rebase to keep history linear when working alone. Merge to preserve context when collaborating. Stage with intention. Push with confidence.
