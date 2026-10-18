Run `tmux-lanes /path/to/lanes.toml` by hand in a tmux window. It reads the
configuration once, refreshes every 15 seconds, and exits on Ctrl-C.

```toml
session = "my-session"
title = "Build lanes"

[[lanes]]
name = "build"
window = "codex"
job = "Implement the feature"
result = "RESULT.md"
end = "#build"
started = 1792300000
```

Repeat `[[lanes]]` for each lane. All fields except `started` are required.
Result paths are absolute or relative to the configuration file; `~` is not
expanded. `started` is Unix seconds, obtainable with `date +%s`. ELAPSED shows
time since that value, including after completion; an absent or future value
shows `-`. RESULT (B) is the file size in bytes; an absent file shows `-`.

An exact `END #build` line in the result marks DONE, including after the window
closes. Otherwise an absent window is MISSING. The active pane's last visible
`Working (...)` or `Worked for ...` line appears under SEAT. The last activity
marker decides RUNNING (`Working (` or `esc to interrupt`) versus IDLE
(`Worked for ...`, or no activity marker).
These are activity hints; only the result marker establishes completion.
Unavailable tmux captures, ambiguous window names, and unreadable results show
ERROR. DONE still takes precedence over unavailable pane data.

Session and window names match exactly. Each refresh lists windows once and
captures each lane's active pane at most once, with a two-second tmux command
budget and bounded cleanup. The board never sends input, starts a tmux server,
or writes files. It installs no bindings or hooks.
