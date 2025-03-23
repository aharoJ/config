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
    set -gx JAVA_HOME (brew --prefix openjdk@21) # default
    # set -gx JAVA_HOME (brew --prefix openjdk@17) # Android SDK
    # set -gx JAVA_HOME (brew --prefix openjdk@11) # MAUI
    set -gx PATH $JAVA_HOME/bin $PATH
end
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ SET NEOVIM AS DEFAULT ~~~~~~~~~~~~~~~~~~~~~ #
function vim
    nvim $argv
end
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ TMUX $JAVA_HOME ~~~~~~~~~~~~~~~~~~~~~ #
if test -n "$TMUX"
    set -gx JAVA_HOME (brew --prefix openjdk@21) # default
    # set -gx JAVA_HOME (brew --prefix openjdk@17) # Android SDK
    # set -gx JAVA_HOME (brew --prefix openjdk@11) # MAUI
    set -gx PATH $JAVA_HOME/bin $PATH
end
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ GITHUB STUFF ~~~~~~~~~~~~~~~~~~~~~ #
set -x GPG_TTY (tty)
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ TMUX | PYTHON VENV STUFF ~~~~~~~~~~~~~~~~~~~~~ #
# set -g project_dir "$HOME/desk/development/python/dcrm-project"
#
# function __auto_venv --on-variable PWD
#     # Check if we're in project root OR any subdirectory
#     if string match -q "$project_dir*" "$PWD"
#         # Only activate if venv exists and not already active
#         if test -e "$project_dir/denv/bin/activate.fish"
#             if not set -q VIRTUAL_ENV
#                 echo "Activating project virtual environment..."
#                 source "$project_dir/denv/bin/activate.fish"
#             end
#         end
#     else
#         # Deactivate only if leaving project entirely
#         if set -q VIRTUAL_ENV
#             echo "Deactivating virtual environment..."
#             deactivate
#         end
#     end
# end
#
# # Initial check when shell starts
# __auto_venv

# DOES NOT WORK WITH TMUX SOOO I WILL NOT USE IT NO MORE 
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ C# Stuff ~~~~~~~~~~~~~~~~~~~~~ #
set -gx ANDROID_HOME ~/Library/Android/sdk
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #
