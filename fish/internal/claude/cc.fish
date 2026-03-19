# path: fish/internal/claude/cc.fish
function cc --description '[claude]: plan-first with bypass permissions'
    claude --permission-mode plan --allow-dangerously-skip-permissions $argv
end
