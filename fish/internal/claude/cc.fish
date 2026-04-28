# path: fish/internal/claude/cc.fish
function cc --description '[claude]: plan-first with bypass permissions; --model-46/--model-47 repins settings.json first'
    argparse --ignore-unknown 'model-46' 'model-47' -- $argv
    or return

    set -l pin_to
    set -q _flag_model_46; and set pin_to "claude-opus-4-6[1m]"
    set -q _flag_model_47; and set pin_to "claude-opus-4-7[1m]"

    if test -n "$pin_to"
        if not command -q jq
            echo "cc: jq required to pin model (brew install jq)" >&2
            return 1
        end
        set -l settings ~/.claude/settings.json
        set -l tmp (mktemp)
        if jq --arg m $pin_to '.model = $m' $settings >$tmp
            mv $tmp $settings
            echo "cc: model -> $pin_to"
        else
            rm -f $tmp
            return 1
        end
    end

    claude --permission-mode plan --allow-dangerously-skip-permissions $argv
end
