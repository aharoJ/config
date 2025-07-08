######## Commands to run in interactive sessions can go here ########
if status is-interactive

    # Editor and greeting
    set -x EDITOR nvim
    set fish_greeting

    # Initialize Starship prompt
    starship init fish | source

    # Ensure Homebrew Python 3.12 has priority
    set -U fish_user_paths /usr/local/opt/python@3.12/libexec/bin $fish_user_paths

    # Cargo (Rust) binaries
    set -U fish_user_paths $HOME/.cargo/bin $fish_user_paths

    # pipx binaries
    set -U fish_user_paths $HOME/.local/bin $fish_user_paths

    # Emacs (MacPorts) - remove if you're no longer using MacPorts Emacs
    set -U fish_user_paths "/Applications/MacPorts/Emacs.app/Contents/MacOS" $fish_user_paths

    # JAVA configuration (default: OpenJDK 21)
    set -gx JAVA_HOME (brew --prefix openjdk@21)
    set -gx PATH $JAVA_HOME/bin $PATH

    # Starship configuration file path
    set -gx STARSHIP_CONFIG ~/.config/starship/starship.toml

    # Android SDK Path (for mobile dev, C# MAUI)
    set -gx ANDROID_HOME ~/Library/Android/sdk

    # GPG configuration for GitHub
    set -x GPG_TTY (tty)

end

# Set Neovim as default editor
function vim
    nvim $argv
end

# Set JAVA_HOME correctly inside TMUX sessions
if test -n "$TMUX"
    set -gx JAVA_HOME (brew --prefix openjdk@21)
    set -gx PATH $JAVA_HOME/bin $PATH
end


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