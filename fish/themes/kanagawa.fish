# KANAGAWA — hand-rolled Fish colors
# Palette (from Kanagawa Wave/Dragon)
set -l fg       DCD7BA  # fujiWhite
set -l subfg    C8C093
set -l dim      6B7089  # dragonGray
set -l bg1      1F1F28  # sumiInk1
set -l bg2      2A2A37  # sumiInk2

set -l pink     D27E99  # sakuraPink
set -l red      E46876  # autumnRed
set -l orange   FFA066  # surimiOrange
set -l yellow   E6C384  # carpYellow / boatYellow
set -l green    98BB6C  # springGreen
set -l cyan     7AA89F  # waveAqua
set -l blue     7E9CD8  # crystalBlue
set -l violet   957FB8  # oniViolet
set -l brown    C0A36E

set -gx COLORTERM truecolor

# ------- syntax ----------
set -g fish_color_normal          $fg
set -g fish_color_command         $blue --bold
set -g fish_color_param           $fg
set -g fish_color_quote           $yellow
set -g fish_color_redirection     $brown
set -g fish_color_end             $green --bold
set -g fish_color_error           $red --bold --underline
set -g fish_color_operator        $pink
set -g fish_color_escape          $cyan
set -g fish_color_autosuggestion  $dim
set -g fish_color_comment         $subfg
set -g fish_color_selection       --background=$bg2
set -g fish_color_search_match    --background=$bg2
set -g fish_color_history_current $fg --bold
set -g fish_color_cwd             $yellow
set -g fish_color_cwd_root        $red
set -g fish_color_host            $violet
set -g fish_color_user            $fg
set -g fish_color_valid_path      $green

# ------- pager -----------
set -g fish_pager_color_prefix            $blue --bold
set -g fish_pager_color_completion        $fg
set -g fish_pager_color_description       $subfg
set -g fish_pager_color_progress          $dim
set -g fish_pager_color_selected_prefix   $blue --bold
set -g fish_pager_color_selected_background --background=$bg1

