# path: fish/internal/claude/cu.fish
function cu --description '[claude]: daily token usage report'
    npx ccusage daily $argv
end
