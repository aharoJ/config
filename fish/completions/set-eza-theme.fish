# ~/.config/fish/completions/set-eza-theme.fish
function __set_eza_theme_completions
    set -l files ~/.config/eza/eza-themes/themes/*.yml
    test -e $files[1]; or return

    # show "(current)" next to the active one
    set -l current ""
    if test -L ~/.config/eza/theme.yml
        set current (basename -s .yml (realpath ~/.config/eza/theme.yml))
    end

    for f in $files
        set -l name (basename -s .yml "$f")
        if test "$name" = "$current"
            echo "$name\t(current)"
        else
            echo $name
        end
    end
end

complete -c set-eza-theme -f -a "(__set_eza_theme_completions)"
