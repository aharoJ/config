# path: fish/internal/claude/_agent_limit.fish
# description: run an AI agent under a reduced hard RLIMIT_NPROC
# patched: new -- fork-exhaustion containment
# date: 2026-08-26
#
# Why this exists: 2026-08-26 a headless Firefox spawned by an agent leaked 5,443
# unreaped children and filled uid 501's process table (kern.maxprocperuid = 6000).
# Every fork/posix_spawn by the user then failed with EAGAIN (errno 35) -- fish, Hammerspoon
# and the agents themselves all died at once. (A bare exec is NOT gated -- only process
# CREATION is, which is why some things kept working and others died.)
#
# RLIMIT_NPROC is compared against the UID-WIDE process count, not a per-tree quota.
# The guardrail works purely by ASYMMETRY: agent trees run at $cap while interactive
# shells stay at the default, so when agents fill the table the operator's shell can
# still fork to diagnose and kill. Consequences of that:
#   * NEVER set this in config.fish or any all-shells location -- capping the operator's
#     own shell reproduces the paralysis this prevents.
#   * NEVER lower the hard limit in the calling function's own shell. Fish functions run
#     in the interactive shell's process and hard limits are one-way, so the pane would
#     stay capped for life. Hence: a disposable child sets the limit, then execs.
# The child uses --no-config so `exec $argv` can never resolve back into a fish function
# (that would recurse), and so it does not pay config.fish startup cost. The agent
# inherits the environment from THIS shell, which did run config.fish.
#
# Boundary is deliberately porous: absolute paths, `command X`, node/npx entry files and
# `tmux new-window <raw agent>` all escape it. That is accepted -- the incident class is
# accidental descendant explosion, not an adversarial escape.
#
# Tune without editing: set -gx AGENT_NPROC_CAP <n>. Not a security control.

function _agent_limit --description 'run an AI agent under a reduced hard RLIMIT_NPROC'
    if test (count $argv) -eq 0
        echo "_agent_limit: no command given" >&2
        return 2
    end

    set -l cap 2000
    if set -q AGENT_NPROC_CAP; and string match -qr '^[0-9]+$' -- "$AGENT_NPROC_CAP"
        set cap $AGENT_NPROC_CAP
    end

    # Resolve to a real executable so the child never re-enters a fish function.
    set -l target $argv[1]
    set -l bin
    if string match -q '*/*' -- $target
        set bin $target
    else
        set bin (command -s $target)
    end
    if test -z "$bin"; or not test -x "$bin"
        echo "_agent_limit: '$target' not found or not executable" >&2
        return 127
    end
    set -e argv[1]

    # Fail OPEN on the limit: if it cannot be lowered (e.g. already lower in a nested
    # agent) the agent still runs. A ulimit quirk must never block the workflow.
    fish --no-config -c "ulimit -S -u $cap 2>/dev/null; ulimit -H -u $cap 2>/dev/null; exec \$argv" $bin $argv
end
