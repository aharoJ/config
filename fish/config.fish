######## Commands to run in interactive sessions can go here ########
if status is-interactive
    
    # Set the EDITOR
    set -x EDITOR nvim

    # Set the fish greeting
    set fish_greeting

    # Initialize Starship prompt
    starship init fish | source

    # NVIM POSTGRESQL
    set -U fish_user_paths $fish_user_paths /Users/aharo/.cargo/bin
    
    # Set Rust's cargo bin path
    set -x PATH "$HOME/.cargo/bin" $PATH

    # Set Python path (Replace with the correct path to your global Python installation)
    set -gx PATH /usr/local/bin/python3 $PATH

    # Ensure Python3 and pip are globally available
    set -gx PATH /usr/local/opt/python@3.13/bin $PATH

    # Remove pyenv configuration
    # PYENV-related paths and initialization are no longer needed
    # set -Ux PYENV_ROOT $HOME/.pyenv
    # set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths

    # Set Emacs path
    set -gx PATH "/Applications/MacPorts/Emacs.app/Contents/MacOS" $PATH

    # Set the Starship configuration path
    set -gx STARSHIP_CONFIG ~/.config/starship/starship.toml

    # Set local bin path created by `pipx`
    set -x PATH $PATH /Users/aharo/.local/bin

    # Set JAVA_HOME and add Java binary to PATH
    set -gx JAVA_HOME (brew --prefix openjdk@17)
    # set -gx JAVA_HOME (brew --prefix openjdk@11)

    set -gx PATH $JAVA_HOME/bin $PATH
end
#################################################################################

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ SET NEOVIM AS DEFAULT ~~~~~~~~~~~~~~~~~~~~~ #
function vim
    nvim $argv
end

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ TMUX | PYTHON VENV STUFF ~~~~~~~~~~~~~~~~~~~~~ #
function auto_venv_check --description "Auto-detects and activates venv"
    # Avoid rechecking if we're in the same directory
    if set -q last_venv_check_dir && test "$PWD" = "$last_venv_check_dir"
        return
    end
    set -g last_venv_check_dir "$PWD"

    # Check if a venv exists in the current directory
    if test -d ./venv
        source ./venv/bin/activate.fish
        return
    end

    # Fastest way to find a venv in parent directories (avoiding `find` overhead)
    set search_path "$PWD"
    while test "$search_path" != "/"
        if test -d "$search_path/venv"
            source "$search_path/venv/bin/activate.fish"
            return
        end
        set search_path (dirname "$search_path")
    end

    # Retain active venv if already activated
    if set -q VIRTUAL_ENV
        echo "Keeping existing venv: $VIRTUAL_ENV"
    end
end

# Automatically trigger when changing directories
function __auto_venv --on-variable PWD
    auto_venv_check
end
