# path: fish/internal/nvim/vim.fish
function vim --wraps=nvim --description 'vim as Neovim'
    if test (count $argv) -eq 0
        nvim 
    else
        nvim $argv
    end
end
complete -c vim -w nvim
