# Gruvbox Dark for Fish (truecolor)
set -g fish_term24bit 1

# palette
set -l gb_fg    "#ebdbb2"
set -l gb_bg    "#282828"
set -l gb_dim   "#a89984"
set -l gb_red   "#fb4934"
set -l gb_green "#b8bb26"
set -l gb_yell  "#fabd2f"
set -l gb_blue  "#83a598"
set -l gb_purp  "#d3869b"
set -l gb_aqua  "#8ec07c"
set -l gb_orng  "#fe8019"
set -l gb_gray  "#928374"

# syntax
set -g fish_color_normal          $gb_fg
set -g fish_color_command         $gb_aqua
set -g fish_color_param           $gb_fg
set -g fish_color_option          $gb_yell
set -g fish_color_operator        $gb_orng
set -g fish_color_quote           $gb_green
set -g fish_color_redirection     $gb_blue
set -g fish_color_end             $gb_orng
set -g fish_color_error           $gb_red
set -g fish_color_comment         $gb_gray
set -g fish_color_valid_path      $gb_blue --underline
set -g fish_color_autosuggestion  $gb_dim
set -g fish_color_escape          $gb_purp
set -g fish_color_selection       --background=$gb_blue --bold
set -g fish_color_search_match    --background=$gb_blue
set -g fish_color_cancel          $gb_red

# optional extras
set -g fish_color_host            $gb_yell
set -g fish_color_host_remote     $gb_yell
set -g fish_color_cwd             $gb_blue
set -g fish_color_cwd_root        $gb_red

# pager/completions
set -g fish_pager_color_prefix                 $gb_orng --bold
set -g fish_pager_color_completion             $gb_fg
set -g fish_pager_color_description            $gb_dim
set -g fish_pager_color_progress               $gb_yell
set -g fish_pager_color_selected_background    --background=$gb_blue
set -g fish_pager_color_secondary_background   --background=$gb_bg
set -g fish_pager_color_selected_completion    $gb_fg
set -g fish_pager_color_selected_description   $gb_dim
set -g fish_pager_color_selected_prefix        $gb_orng --bold
