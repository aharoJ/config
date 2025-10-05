function t --wraps=tmux --description 'Tmux: no args -> attach; args -> passthrough'
    if test (count $argv) -eq 0
        tmux attach || tmux new
    else
        tmux $argv
    end
end
complete -c t -w tmux
