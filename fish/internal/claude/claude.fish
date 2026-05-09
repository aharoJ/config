# path: fish/internal/claude/claude.fish
# Wraps the claude binary with a subagent-routing safety hint.
# Warns when CLAUDE_CODE_SUBAGENT_MODEL is unset, so raw `claude` invocations
# can't silently spawn Opus children from Opus parents. cc.fish wrappers pin
# SUBAGENT_MODEL locally per role, so they bypass the warning.
# Background: parked review-protocol topic "subagent-routing trust boundary".

function claude --description 'Claude Code with subagent-routing safety hint'
    if not set -q CLAUDE_CODE_SUBAGENT_MODEL
        echo 'cc warn: CLAUDE_CODE_SUBAGENT_MODEL unset; subagents inherit parent tier' >&2
        echo '         use a cc role, or `set -gx CLAUDE_CODE_SUBAGENT_MODEL <model>` ad-hoc' >&2
    end
    command claude $argv
end
