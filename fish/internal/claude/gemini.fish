# path: fish/internal/claude/gemini.fish
# description: Gemini CLI under the shared agent process cap
# patched: new -- fork-exhaustion containment
# date: 2026-08-26
#
# gemini was previously invoked as a raw binary with no fish wrapper, so it had no
# containment boundary. See _agent_limit for the rationale and its known porosity.

function gemini --wraps gemini --description 'Gemini CLI under the agent process cap'
    _agent_limit gemini $argv
end
