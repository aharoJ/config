function deepseek --description "Claude Code backed by DeepSeek (V4 Flash default, --v4-pro to escalate)"
    if not set -q DEEPSEEK_API_KEY
        echo "DEEPSEEK_API_KEY not set"
        return 1
    end

    set -l model "deepseek-v4-flash"
    set -l argv_clean
    set -l options 1
    set -l raw_model 0
    for arg in $argv
        if test $options -eq 0
            set -a argv_clean "$arg"
            continue
        end
        switch $arg
            case --
                set options 0
                set -a argv_clean "$arg"
            case --dangerously-skip-permissions
                # The wrapper supplies this once below.
            case -v4-pro
                echo "deepseek: unknown flag -v4-pro (did you mean --v4-pro?)" >&2
                return 1
            case --v4-pro
                set model "deepseek-v4-pro"
            case --model '--model=*' -m '-m*'
                set raw_model 1
                set -a argv_clean "$arg"
            case '*'
                set -a argv_clean "$arg"
        end
    end
    if test "$model" = deepseek-v4-pro; and test $raw_model -eq 1
        echo "deepseek: raw --model/-m cannot be combined with --v4-pro" >&2
        return 2
    end
    set argv $argv_clean

    set -lx ANTHROPIC_BASE_URL                        "https://api.deepseek.com/anthropic"
    set -lx ANTHROPIC_AUTH_TOKEN                       $DEEPSEEK_API_KEY
    set -lx ANTHROPIC_MODEL                            $model"[1m]"
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL               $model
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL             $model
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL              $model
    set -lx CLAUDE_CODE_SUBAGENT_MODEL                 $model
    set -lx CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC   1
    set -lx CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK  1

    # CC 2.1.154 REGRESSION: it injects `role: system` messages into messages[]
    # -- the skills list (messages[1]) AND live system-reminders mid-session (the
    # "task tools haven't been used" nudge, etc.) AND subagent sidechain
    # artifacts. DeepSeek's strict Anthropic-compat deserializer rejects any role
    # != user/assistant -> `messages[N].role: unknown variant system` 400. There
    # is NO CC config that disables reminder injection (verified: --bare,
    # --disallowedTools, and every relevant env var do not stop it). --disallow
    # Skill only killed messages[1], so long/agentic sessions still broke.
    #
    # 2.1.153 is the last version that injects ZERO role:system messages (verified
    # by capturing both versions' request bodies). So the DeepSeek path is PINNED
    # to 2.1.153. The real-Claude `cc` roles keep using the current binary on
    # PATH. Re-test newer CC periodically; drop this pin once the regression is
    # fixed upstream. Reinstall the pin with:
    #   npm install --prefix ~/.local/cc-pinned-2.1.153 @anthropic-ai/claude-code@2.1.153
    #
    # Thinking stays ON (DeepSeek reasons; signed blocks replay fine). Only ESC
    # mid-thinking can wedge a session (CC saves an unsigned thinking block) -- if
    # that happens, /clear; don't keep typing. Hard-disable via:
    # set -lx CLAUDE_CODE_DISABLE_THINKING 1
    set -l cc_pinned "$HOME/.local/cc-pinned-2.1.153/node_modules/.bin/claude"
    if not test -x "$cc_pinned"
        echo "deepseek: pinned CC 2.1.153 not found at $cc_pinned" >&2
        echo "          reinstall: npm install --prefix ~/.local/cc-pinned-2.1.153 @anthropic-ai/claude-code@2.1.153" >&2
        return 1
    end
    _agent_limit $cc_pinned --dangerously-skip-permissions $argv
end
