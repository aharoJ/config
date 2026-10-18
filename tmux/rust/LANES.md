Run `tmux-lanes /path/to/lanes.toml` by hand in a tmux window. It reads the
configuration again every 15 seconds and exits on Ctrl-C. A broken or missing
file during a save leaves the last valid board running with a short warning;
the next valid version replaces it and clears the warning. An invalid file at
startup exits with an error.

```toml
session = "my-session"
title = "Build lanes"
footer = ["Next: inspect the build result", "Records: ./results"]

[[lanes]]
name = "build"
window = "codex"
job = "Implement the feature"
result = "RESULT.md"
end = "#build"
started = 1792300000
```

Repeat `[[lanes]]` for each lane. `footer` and `started` are optional; the other
fields are required. Put the top-level `footer` list before `[[lanes]]`.
Footer lines must be nonempty single lines; long lines wrap to fit the window.
Result paths are absolute or relative to the configuration file; `~` is not
expanded. `started` is Unix seconds, obtainable with `date +%s`. ELAPSED shows
time since that value while incomplete. At DONE it uses the result file's
last-write time as an approximate finish time, so the duration stops growing.
This estimates when the result was written, not exact worker runtime; later
edits to the result can change the estimate. Missing or inconsistent times
show `-`. RESULT (B) is the file size in bytes; an absent file shows `-`.

An exact `END #build` line in the result marks DONE, including after the window
closes, and its SEAT shows `result complete`. Otherwise an absent window is
MISSING. The active pane's last visible
`Working (...)` or `Worked for ...` line appears under SEAT. The last activity
marker decides RUNNING (`Working (` or `esc to interrupt`) versus IDLE
(`Worked for ...`, or no activity marker).
These are activity hints; only the result marker establishes completion.
Unavailable tmux captures, ambiguous window names, and unreadable results show
ERROR. DONE still takes precedence over unavailable pane data.

The header shows `updated HH:MM:SS` in local time for the collected frame. JOB
shortens first as the window narrows. At 60 columns each lane uses two rows:
name, state, elapsed, and result size stay together; JOB and SEAT move below.
Very small windows stack and wrap the fields instead. Labels remain plain text.

Session and window names match exactly. Each refresh lists windows once and
captures each lane's active pane at most once, with a two-second tmux command
budget and bounded cleanup. The board never sends input, starts a tmux server,
or writes files. It installs no bindings or hooks.
