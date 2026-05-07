function pyenv --wraps pyenv
    _pyenv_lazy_init
    pyenv $argv
end
