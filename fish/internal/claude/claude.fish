# path: fish/internal/claude/claude.fish
# Wraps the claude binary with a subagent-routing safety hint.
# On current CC, CLAUDE_CODE_SUBAGENT_MODEL is a fallback: explicit subagent
# model choices take precedence. cc.fish sets a local Sonnet fallback.
# Raw `claude` warns when it is unset; subagents may inherit the parent tier.
# Background: parked review-protocol topic "subagent-routing trust boundary".

function claude --description 'Claude Code with subagent-routing safety hint'
    if not set -q CLAUDE_CODE_SUBAGENT_MODEL
        echo 'cc warn: CLAUDE_CODE_SUBAGENT_MODEL unset; subagents may inherit parent tier' >&2
        echo '         use cc for a Sonnet subagent fallback' >&2
    end
    _agent_limit claude $argv
end
