

``` sh
#SKHD STUFF ~ type  skhd --observe  in a terminal and type a key
# HYPER == SHIFT + CMD + ALT + OPTION
# CREDITS: https://aharoj.io

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     WINDOW | PANES     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# SWAP  <~~>  WINDOWS
shift + alt - j : yabai -m window --swap south
shift + alt - k : yabai -m window --swap north
hyper - 0x21 : yabai -m window --swap west ## 0x21 is the "[" key
hyper - 0x1E : yabai -m window --swap east ## 0x1E is the "]" key

# Navigation Panes
hyper - h : yabai -m window --focus west     # h <-
hyper - j : yabai -m window --focus south    # j v
hyper - k : yabai -m window --focus north    # k ^
hyper - l : yabai -m window --focus east     # l ->

# Set insertion point for focused container  ~ like it highlights were the new pane will spawn ~ 
alt - h : yabai -m window --insert west      # h <-
alt - j : yabai -m window --insert south     # j v
alt - k : yabai -m window --insert north     # k ^
alt - l : yabai -m window --insert east      # l ->

# Window Resizing Shortcuts (Increase Size)
hyper - y : yabai -m window --resize left:-20:0  # y <-
hyper - u : yabai -m window --resize bottom:0:20 # u v
hyper - i : yabai -m window --resize top:0:-20   # i ^
hyper - o : yabai -m window --resize right:20:0  # o ->

# Window Resizing Shortcuts (Decrease Size)
hyper - m : yabai -m window --resize left:20:0    # v <-
hyper - n : yabai -m window --resize bottom:0:-20 # b v
hyper - b : yabai -m window --resize top:0:20     # n ^
hyper - v : yabai -m window --resize right:-20:0  # m ->
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #




# ~~~~~~~~~~~~~~~~~~~~~~~~     Workspaces == Desktop     ~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
shift + alt - m : yabai -m window --space last; yabai -m space --focus last
shift + alt - p : yabai -m window --space prev; yabai -m space --focus prev
shift + alt - n : yabai -m window --space next; yabai -m space --focus next

shift + alt - 1 : yabai -m window --space 1; yabai -m space --focus 1
shift + alt - 2 : yabai -m window --space 2; yabai -m space --focus 2
shift + alt - 3 : yabai -m window --space 3; yabai -m space --focus 3
shift + alt - 4 : yabai -m window --space 4; yabai -m space --focus 4

hyper - 1 : yabai -m space --focus 1
hyper - 2 : yabai -m space --focus 2
hyper - 3 : yabai -m space --focus 3
hyper - 4 : yabai -m space --focus 4

cmd + alt - w : yabai -m space --destroy ## destroy desktop
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~       TERMINAL         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# hyper - a : /Applications/Alacritty.app/Contents/MacOS/alacritty
hyper - z : /Applications/kitty.app/Contents/MacOS/kitty
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~       ROTATING         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
hyper - r : yabai -m space --rotate 90     # rotate tree 90
hyper - x : yabai -m space --mirror x-axis # Rotate on X Axis 
hyper - e : yabai -m space --mirror y-axis # Rotate on Y Axis
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~      RANDOM GEMS       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
hyper - 0x1B : yabai -m window --toggle split                                  # toggle window split type ~ ~ ~ 0x1B is the "-" key
shift + alt - b : yabai -m window --toggle border                              # toggle window border
hyper - f : yabai -m window --toggle zoom-fullscreen                           # toggle window fullscreen zoom
hyper - t : yabai -m window --toggle float;\yabai -m window --grid 4:4:1:1:2:2 # toggle sticky 
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
```




