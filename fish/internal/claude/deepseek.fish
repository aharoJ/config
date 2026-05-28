function deepseek --description "Claude Code backed by DeepSeek (V4 Flash default, --v4-pro to escalate)"
    if not set -q DEEPSEEK_API_KEY
        echo "DEEPSEEK_API_KEY not set"
        return 1
    end

    set -l model "deepseek-v4-flash"
    if contains -- --v4-pro $argv
        set model "deepseek-v4-pro"
        set -l argv_clean
        for arg in $argv
            test "$arg" != "--v4-pro"; and set -a argv_clean $arg
        end
        set argv $argv_clean
    end

    set -lx ANTHROPIC_BASE_URL                        "https://api.deepseek.com/anthropic"
    set -lx ANTHROPIC_AUTH_TOKEN                       $DEEPSEEK_API_KEY
    set -lx ANTHROPIC_MODEL                            $model"[1m]"
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL               $model
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL             $model
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL              $model
    set -lx CLAUDE_CODE_SUBAGENT_MODEL                 $model
    set -lx CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC   1
    set -lx CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK  1
    set -lx CLAUDE_CODE_EFFORT_LEVEL                   "max"
    set -lx API_TIMEOUT_MS                             600000

    # CC 2.1.154 injects the skills list as a `role: system` message inside the
    # messages[] array. DeepSeek's strict Anthropic-compat deserializer rejects
    # any role other than user/assistant -> `messages[1].role: unknown variant
    # system` 400 on EVERY request (2.1.153 did not do this -> CC regression).
    # Dropping the Skill tool removes that message. Scoped to this wrapper, not
    # global settings.json, so the real-Claude `cc` roles keep their skills.
    #
    # Thinking stays ON: DeepSeek reasons and its signed thinking blocks replay
    # fine. The one failure mode is pressing ESC mid-thinking -- CC persists the
    # partial reasoning as an UNSIGNED thinking block that wedges the session on
    # replay (sticky 400 on every later message). If that happens: /clear, don't
    # keep typing. To harden against it entirely, uncomment the next line:
    # set -lx CLAUDE_CODE_DISABLE_THINKING 1
    claude --dangerously-skip-permissions --disallowedTools Skill $argv
end
