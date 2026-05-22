# path: ~/.config/fish/config.fish

# ---- Globals / env that should exist in ALL shells --------------------------
set -gx STARSHIP_CONFIG "$HOME/.config/starship/starship.toml"
set -gx EZA_CONFIG_DIR ~/.config/eza

# Homebrew (skip re-eval in nested shells — saves 24ms per nest)
if test -d /opt/homebrew; and not set -q HOMEBREW_PREFIX
    eval (/opt/homebrew/bin/brew shellenv)
end

# pyenv (Python) — eager PATH prepend so non-interactive shells
# (Claude Code Bash tool, scripts, IDEs spawning bash -c) resolve `python3`
# via pyenv shims instead of falling through to /usr/bin/python3 = 3.9.
# Why eager: bash -c does not source ~/.bashrc, so the pyenv-prepend block
# in ~/.bashrc never runs for tool-spawned bash; that bash inherits PATH
# from its parent (Claude Code), which inherited from this fish process.
# The lazy fish function stubs in internal/python/ remain in place for
# interactive use (completions, rehash hooks via `pyenv init`).
if test -d "$HOME/.pyenv/shims"
    set -gx PYENV_ROOT "$HOME/.pyenv"
    # Remove any existing entry, then prepend, so nested fish sessions that
    # inherited PATH with shims at a later position (e.g., from Claude Code
    # parent) get re-promoted to position 1. Mirrors the jenv pattern below.
    while set -l _idx (contains -i -- "$PYENV_ROOT/shims" $PATH)
        set -e PATH[$_idx]
    end
    set -gx PATH "$PYENV_ROOT/shims" $PATH
end

# BASH_ENV: forces non-interactive bash (`bash -c`) to source ~/.bashrc.
# Without this, bash spawned with `bash -c` from fish (LLM Bash tools,
# scripts, IDEs) skips ~/.bashrc entirely and inherits PATH from parent.
# When the parent's PATH happens to be wrong, python3 falls through to
# /usr/bin/python3 = 3.9. Setting BASH_ENV makes bash always re-apply the
# pyenv remove-then-prepend in ~/.bashrc, self-correcting any inherited
# PATH ordering. Idempotent because ~/.bashrc uses remove-then-prepend.
set -gx BASH_ENV "$HOME/.bashrc"

# Editors
set -gx EDITOR nvim
set -gx VISUAL nvim

# (Optional) Silence the greeting
set -g fish_greeting ""

# internal/notes..
set -gx NOTES_DIR "$HOME/notes"

# ~~~ OPUS 4.6 ~~~
# set -gx CLAUDE_CODE_EFFORT_LEVEL max
# set -gx CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING 1
# set -gx MAX_THINKING_TOKENS 31999
# set -gx CLAUDE_CODE_SUBAGENT_MODEL claude-sonnet-4-6
# ~~~ END ~~~



# Autoload functions from internal/* subdirs (glob, no subprocess)
set -l _root "$HOME/.config/fish/internal"
if test -d "$_root"
    for dir in $_root/**/
        set dir (string trim -r -c / -- $dir)
        if not contains -- $dir $fish_function_path
            set -g fish_function_path $dir $fish_function_path
        end
    end
end

# Define Codex wrapper eagerly so model and approval flags do not fall through
# to the raw binary before Fish autoload has resolved the function.
if test -f "$HOME/.config/fish/internal/codex/codex.fish"
    source "$HOME/.config/fish/internal/codex/codex.fish"
end

# ---- Interactive-only stuff -------------------------------------------------
if status is-interactive
    # Prompt
    starship init fish | source
    source ~/.config/fish/themes/gruvbox.fish

    # jenv (Java) -- shims first, lazy shell integration on first jenv call
    set -gx JENV_ROOT "$HOME/.jenv"
    if test -d "$JENV_ROOT/shims"
        while set -l _idx (contains -i -- "$JENV_ROOT/shims" $PATH)
            set -e PATH[$_idx]
        end
        set -gx PATH "$JENV_ROOT/shims" $PATH
    end

    function __jenv_lazy_init
        functions -e jenv __jenv_lazy_init
        if not command -q jenv
            return 127
        end
        set -gx JENV_SHELL fish
        set -gx JENV_LOADED 1
        set -e JAVA_HOME
        set -e JDK_HOME
        function jenv --wraps jenv
            set -l command $argv[1]
            set -e argv[1]
            switch "$command"
                case enable-plugin rehash shell shell-options
                    command jenv "sh-$command" $argv | source
                case '*'
                    command jenv "$command" $argv
            end
        end
        for _script in (command jenv hooks init fish 2>/dev/null)
            source "$_script"
        end
    end

    function jenv --wraps jenv
        __jenv_lazy_init; or return $status
        jenv $argv
    end

    # fnm (Node)
    if type -q fnm
        fnm env --use-on-cd | source
    end

    # pyenv (Python) — lazy-init via internal/python/ stubs (75ms deferred to first use)

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

    # Ctrl+D: delete char if line has content, do nothing if empty.
    # Prevents pane death when Kimi (which uses Ctrl+D as its copy key) leaks
    # extra keypresses into the shell prompt.
    bind \cd 'set -l _cmd (commandline); if test (string length -- "$_cmd") -gt 0; commandline -f delete-char; end'


    alias n="NVIM_APPNAME=nvim-rebuild nvim"
    alias nvim-v3="NVIM_APPNAME=nvim-v3 nvim"




end
