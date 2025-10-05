# CATPPUCCIN MACCHIATO — Fish colors
# Palette
set -l base     24273A
set -l mantle   1E2030
set -l text     CAD3F5
set -l subtext  B8C0E0
set -l overlay0 6E738D

set -l red      ED8796
set -l maroon   EE99A0
set -l peach    F5A97F
set -l yellow   EED49F
set -l green    A6DA95
set -l teal     8BD5CA
set -l sky      91D7E3
set -l sapphire 7DC4E4
set -l blue     8AADF4
set -l lavender B7BDF8
set -l mauve    C6A0F6
set -l pink     F5BDE6
set -l flamingo F0C6C6

set -gx COLORTERM truecolor

# ------- syntax ----------
set -g fish_color_normal          $text
set -g fish_color_command         $mauve --bold
set -g fish_color_param           $text
set -g fish_color_quote           $yellow
set -g fish_color_redirection     $teal
set -g fish_color_end             $green --bold
set -g fish_color_error           $red --bold --underline
set -g fish_color_operator        $pink
set -g fish_color_escape          $sapphire
set -g fish_color_autosuggestion  $overlay0
set -g fish_color_comment         $subtext
set -g fish_color_selection       --background=$mantle
set -g fish_color_search_match    --background=$mantle
set -g fish_color_history_current $text --bold
set -g fish_color_cwd             $yellow
set -g fish_color_cwd_root        $red
set -g fish_color_host            $lavender
set -g fish_color_user            $text
set -g fish_color_valid_path      $green

# ------- pager -----------
set -g fish_pager_color_prefix            $mauve --bold
set -g fish_pager_color_completion        $text
set -g fish_pager_color_description       $subtext
set -g fish_pager_color_progress          $overlay0
set -g fish_pager_color_selected_prefix   $mauve --bold
set -g fish_pager_color_selected_background --background=$base

