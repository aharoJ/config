function pip3 --wraps pip3
    _pyenv_lazy_init
    command pip3 $argv
end
