function gemini --wraps agy --description 'Gemini seat (Agy) under the agent process cap'
    _agent_limit agy --dangerously-skip-permissions $argv
end
