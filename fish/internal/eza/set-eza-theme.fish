function set-eza-theme
    set -l themes_dir "$HOME/.config/eza/eza-themes/themes"

    # if no argument given → list all themes
    if test (count $argv) -eq 0
        echo "Available themes:"
        for theme in (ls $themes_dir | string replace -r '\.yml$' '')
            echo "  $theme"
        end
        return 0
    end

    # if argument provided → set the theme
    set -l theme_file "$themes_dir/$argv[1].yml"
    if not test -e "$theme_file"
        echo "Theme '$argv[1]' not found."
        echo "Run 'set-eza-theme' with no args to list available themes."
        return 1
    end

    ln -sf "$theme_file" "$HOME/.config/eza/theme.yml"
    echo "✅ eza theme set to: $argv[1]"
end
