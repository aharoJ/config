# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ Interactive session setup ~~~~~~~~~~~~~~~~~~~~~ #
if status is-interactive
    # Environment variables
    set -gx EDITOR nvim # Default editor
    set -gx fish_greeting # Disable Fish greeting
    set -gx STARSHIP_CONFIG ~/.config/starship/starship.toml # Starship prompt config
    set -gx ANDROID_HOME ~/Library/Android/sdk # Android SDK for mobile dev
    set -gx GPG_TTY (tty) # GPG for GitHub

    # Initialize Starship prompt
    starship init fish | source
end
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~      Path      ~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
fish_add_path /usr/local/opt/python@3.12/libexec/bin # Homebrew Python 3.12
fish_add_path $HOME/.cargo/bin # Cargo (Rust) binaries
fish_add_path $HOME/.local/bin # pipx binaries
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ Java setup ~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# Java configuration (OpenJDK 21)
set -gx JAVA_HOME (brew --prefix openjdk@21)
set -gx PATH $JAVA_HOME/bin $PATH
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ Functions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
function vim --description 'Use Neovim as vim'
    nvim $argv
end

function v --description 'Use Neovim as v'
    nvim $argv
end

function ys --description 'Start yabai service'
    yabai --start-service
end

function yr --description 'Restart yabai service'
    yabai --restart-service
end

function yS --description 'Stop yabai service'
    yabai --stop-service
end
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ TMUX-specific setup ~~~~~~~~~~~~~~~~~~~~~~~~~~ #
if test -n "$TMUX"
    set -gx JAVA_HOME (brew --prefix openjdk@21)
    set -gx PATH $JAVA_HOME/bin $PATH
end
# ~~~~~~~~~~~~~~~~~~~           ..................       ~~~~~~~~~~~~~~~~~~~ #
