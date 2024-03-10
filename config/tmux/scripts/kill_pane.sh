#!/bin/bash

# Get the number of panes in the current session
pane_count=$(tmux list-panes | wc -l)

# If there's only one pane left, ask for confirmation
if [ "$pane_count" -eq 1 ]; then
    read -p "This will close the last pane and end the session. Continue? (y/n) " -n 1 -r
    echo    # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux kill-pane
    fi
else
    tmux kill-pane
fi

