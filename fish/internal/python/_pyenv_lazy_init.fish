function _pyenv_lazy_init
    functions -e python python3 pip pip3 pyenv _pyenv_lazy_init
    set -gx PYENV_ROOT "$HOME/.pyenv"
    pyenv init --no-rehash - | source
end
