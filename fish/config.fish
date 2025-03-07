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
    set -gx JAVA_HOME (brew --prefix openjdk@21)
    # set -gx JAVA_HOME (brew --prefix openjdk@17)
    # set -gx JAVA_HOME (brew --prefix openjdk@11)

    set -gx PATH $JAVA_HOME/bin $PATH
end
#################################################################################

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ SET NEOVIM AS DEFAULT ~~~~~~~~~~~~~~~~~~~~~ #
function vim
    nvim $argv
end

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ TMUX $JAVA_HOME ~~~~~~~~~~~~~~~~~~~~~ #
if test -n "$TMUX"
    set -gx JAVA_HOME (brew --prefix openjdk@21)
    set -gx PATH $JAVA_HOME/bin $PATH
end


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ GITHUB STUFF ~~~~~~~~~~~~~~~~~~~~~ #
set -x GPG_TTY (tty)




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ TMUX | PYTHON VENV STUFF ~~~~~~~~~~~~~~~~~~~~~ #
function auto_venv_check --description "Smart venv management"
    # Check exact directory match first
    if test -n "$VIRTUAL_ENV" && string match -q "$VIRTUAL_ENV" (pwd -P)/venv
        return
    end

    # Current directory check
    if test -e ./venv/bin/activate.fish
        source ./venv/bin/activate.fish >/dev/null 2>&1
        return
    end

    # Parent directory search (3 levels)
    set -l parent (pwd -P)
    for i in 1 2 3
        set parent (dirname "$parent")
        if test -e "$parent/venv/bin/activate.fish"
            source "$parent/venv/bin/activate.fish" >/dev/null 2>&1
            return
        end
        test "$parent" = "/" && break
    end

    # Clean deactivation
    if set -q VIRTUAL_ENV && functions -q deactivate
        deactivate >/dev/null 2>&1
    end
end

# Prevent duplicate checks during rapid directory changes
function __force_venv_check --on-variable PWD
    set -l dir_id (stat -c %i:%d . 2>/dev/null || stat -f %i:%d .)
    if not set -q __venv_last_id || test "$dir_id" != "$__venv_last_id"
        auto_venv_check
        set -g __venv_last_id "$dir_id"
    end
    commandline -f repaint
end

# Initialize for new shells
auto_venv_check




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ C# Stuff ~~~~~~~~~~~~~~~~~~~~~ #

