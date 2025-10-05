# fish/internal/nvim/v.fish
function v --wraps=nvim --description 'v as Neovim'
    if test (count $argv) -eq 0
        nvim 
    else
        nvim $argv
    end
end
complete -c v -w nvim
