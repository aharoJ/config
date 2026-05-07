function pip --wraps pip
    _pyenv_lazy_init
    command pip $argv
end
