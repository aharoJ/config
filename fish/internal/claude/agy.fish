# path: fish/internal/claude/agy.fish
# description: Antigravity CLI (agy) under the shared agent process cap
# patched: new -- fork-exhaustion containment
# date: 2026-08-26
#
# agy was previously invoked as a raw binary with no fish wrapper, so it had no
# containment boundary. See _agent_limit for the rationale and its known porosity.

function agy --wraps agy --description 'Antigravity CLI (agy) under the agent process cap'
    _agent_limit agy $argv
end
