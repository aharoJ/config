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

    claude --dangerously-skip-permissions $argv
end
