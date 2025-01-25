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

# Set Neovim as default editor for Vim commands
function vim
    nvim $argv
end
