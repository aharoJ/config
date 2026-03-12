# path: ~/.config/fish/internal/yazi/lf.fish
function lf --description 'nvim + yazi (unified)'
    NVIM_APPNAME=nvim-rebuild nvim +"autocmd VimEnter * ++once Yazi"
end
