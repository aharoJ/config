# path: ~/.config/fish/config.fish

# ---- Globals / env that should exist in ALL shells --------------------------
set -gx STARSHIP_CONFIG "$HOME/.config/starship/starship.toml"
set -Ux EZA_CONFIG_DIR ~/.config/eza

# Homebrew (path first so tools resolve correctly in scripts too)
if test -d /opt/homebrew
    eval (/opt/homebrew/bin/brew shellenv)
end

# Editors
set -gx EDITOR nvim
set -gx VISUAL nvim

# (Optional) Silence the greeting
set -g fish_greeting ""

# Autoload functions from internal/* subdirs
set -l _root "$HOME/.config/fish/internal"
if test -d "$_root"
    for dir in (find "$_root" -type d)
        if not contains -- "$dir" $fish_function_path
            set -g fish_function_path $dir $fish_function_path
        end
    end
end

# ---- Interactive-only stuff -------------------------------------------------
if status is-interactive
    # Prompt
    starship init fish | source
    source ~/.config/fish/themes/gruvbox.fish

    # jenv (Java)
    set -gx JENV_ROOT "$HOME/.jenv"
    if test -d "$JENV_ROOT"
        fish_add_path "$JENV_ROOT/bin"
        jenv init - | source
    end

    # fnm (Node)
    if type -q fnm
        fnm env --use-on-cd | source
    end

    # pyenv (Python)
    if type -q pyenv
        # Prefer -gx over -Ux to avoid writing universal vars every launch
        set -gx PYENV_ROOT "$HOME/.pyenv"
        fish_add_path "$PYENV_ROOT/bin"
        pyenv init - | source
    end

    # direnv
    if type -q direnv
        direnv hook fish | source
    end

    # Aliases & abbrs (interactive convenience)
    # alias la="eza -la --group-directories-first --color=always"
    # alias lg="eza -l --git --color=always"
    # alias l1="eza -1 --group-directories-first"
    # alias lS="eza -l --sort=size"
    # alias lt2="eza -T --level=2"

    alias ls="eza --group-directories-first --color=always --icons"
    alias la="eza -a --group-directories-first --color=always --icons"
    alias ll="eza -l -a -h --no-filesize --group-directories-first --color=always --icons"
    alias ld="eza -a -l --header --created --accessed --changed --no-user --no-filesize --time-style=relative --icons"
    alias lr="eza -R -a -h --group-directories-first --color=always --icons"
    alias lt="eza -T --color=always --icons"

    abbr .. "cd .."
    abbr ... "cd ../.."


    alias n="NVIM_APPNAME=nvim-rebuild nvim"




end
