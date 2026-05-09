function openrouter --description "Qwen Code via OpenRouter (requires exactly one --model-{name} flag)"
    set -l flag_count 0
    set -l model ""

    for arg in $argv
        switch $arg
            case --model-qwen-coder
                set model "qwen/qwen3-coder-plus"
                set flag_count (math $flag_count + 1)
            case --model-qwen-plus
                set model "qwen/qwen3.6-plus"
                set flag_count (math $flag_count + 1)
            case --model-qwen-max
                set model "qwen/qwen3.6-max-preview"
                set flag_count (math $flag_count + 1)
            case --model-glm
                set model "z-ai/glm-4.5-air:free"
                set flag_count (math $flag_count + 1)
        end
    end

    for arg in $argv
        switch $arg
            case --model-qwen-coder --model-qwen-plus --model-qwen-max --model-glm
                # allowed wrapper model flag
            case --model-qwen-coder-plus --model-qwen-3-6-plus
                echo "openrouter: legacy model flag renamed; use --model-qwen-coder or --model-qwen-plus" >&2
                return 2
            case '--model-*'
                echo "openrouter: unknown wrapper model flag; use exactly one listed --model-{name} flag" >&2
                return 2
            case --model '--model=*' -m '-m=*' '-m*'
                echo "openrouter: raw --model/-m not allowed (cost-safety); use --model-{name} flags only" >&2
                return 2
            case --openai-base-url '--openai-base-url=*' --openai-api-key '--openai-api-key=*' --auth-type '--auth-type=*' --openaiBaseUrl '--openaiBaseUrl=*' --openaiApiKey '--openaiApiKey=*' --authType '--authType=*'
                echo "openrouter: raw OpenAI/OpenRouter auth routing flags are not allowed; wrapper owns auth and base URL" >&2
                return 2
        end
    end

    if test $flag_count -eq 0
        echo "openrouter: model flag required" >&2
        echo "" >&2
        echo "Usage:" >&2
        echo "  openrouter --model-qwen-coder  |  qwen/qwen3-coder-plus     |  (paid, code-tuned)" >&2
        echo "  openrouter --model-qwen-plus   |  qwen/qwen3.6-plus         |  (paid, newest gen)" >&2
        echo "  openrouter --model-qwen-max    |  qwen/qwen3.6-max-preview  |  (paid, heaviest)" >&2
        echo "  openrouter --model-glm         |  z-ai/glm-4.5-air:free     |  (free)" >&2
        return 2
    end

    if test $flag_count -gt 1
        echo "openrouter: exactly one --model-{name} flag required (got $flag_count)" >&2
        return 2
    end

    set -l argv_clean
    for arg in $argv
        switch $arg
            case --model-qwen-coder --model-qwen-plus --model-qwen-max --model-glm
                # strip wrapper-only flag
            case '*'
                set -a argv_clean $arg
        end
    end

    set -l key (jq -r '.env.OPENROUTER_API_KEY // empty' ~/.qwen/settings.json 2>/dev/null)
    if test -z "$key"
        echo "OPENROUTER_API_KEY not found in ~/.qwen/settings.json" >&2
        return 1
    end

    set -lx OPENAI_API_KEY $key
    set -lx OPENAI_BASE_URL "https://openrouter.ai/api/v1"

    command qwen \
        --auth-type openai \
        --openai-base-url "https://openrouter.ai/api/v1" \
        --model $model $argv_clean
end
