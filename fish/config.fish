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
function auto_venv_check --description "Ultra-optimized venv management"
    # Lightweight directory fingerprint using inode metadata
    set -l dir_id (stat -f '%i:%d' . 2>/dev/null || stat -c '%i:%d' .)
    if set -q __venv_last_id && test "$dir_id" = "$__venv_last_id"
        return
    end
    set -g __venv_last_id "$dir_id"

    # Check cached venv path first (instant exit for common case)
    if set -q VIRTUAL_ENV
        if string match -q "$VIRTUAL_ENV" "$PWD"/venv
            return
        else if string match -q "$VIRTUAL_ENV" "$PWD"/*/venv
            return
        end
    end

    # Memory-optimized parent directory search
    set -l search_path (pwd -P)
    set -l max_depth 3
    set -l found false

    for i in (seq $max_depth)
        if test -e "$search_path/venv/bin/activate.fish"
            set found true
            break
        end
        test "$search_path" = "/" && break
        set search_path (dirname "$search_path")
    end

    # Fast path: No venv found anywhere
    if not $found
        set -q VIRTUAL_ENV && deactivate
        return
    end

    # Only reactivate if venv path changed
    if not set -q VIRTUAL_ENV || test "$VIRTUAL_ENV" != "$search_path/venv"
        source "$search_path/venv/bin/activate.fish"
    end
end

function __auto_venv --on-variable PWD
    auto_venv_check
end
