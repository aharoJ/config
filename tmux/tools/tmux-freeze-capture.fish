#!/usr/bin/env fish
set -l socket (string trim -- ""$TMUX_FREEZE_CAPTURE_SOCKET)
set -l output_root (string trim -- ""$TMUX_FREEZE_CAPTURE_OUTPUT_ROOT)
set -l tmux_bin (string trim -- ""$TMUX_FREEZE_CAPTURE_TMUX_BIN)
set -l timeout_bin (string trim -- ""$TMUX_FREEZE_CAPTURE_TIMEOUT_BIN)
set -l lsof_bin (string trim -- ""$TMUX_FREEZE_CAPTURE_LSOF_BIN)
set -l sample_bin (string trim -- ""$TMUX_FREEZE_CAPTURE_SAMPLE_BIN)
set -l tmux_seconds (string trim -- ""$TMUX_FREEZE_CAPTURE_TMUX_TIMEOUT_SECONDS)
set -l lsof_seconds (string trim -- ""$TMUX_FREEZE_CAPTURE_LSOF_TIMEOUT_SECONDS)
set -l sample_seconds (string trim -- ""$TMUX_FREEZE_CAPTURE_SAMPLE_TIMEOUT_SECONDS)
test -n "$socket"; or set socket /private/tmp/tmux-501/default
test -n "$output_root"; or set output_root "$HOME/Desktop"
test -n "$tmux_bin"; or set tmux_bin (command -s tmux)
test -n "$timeout_bin"; or set timeout_bin (command -s timeout)
test -n "$timeout_bin"; or set timeout_bin (command -s gtimeout)
test -n "$lsof_bin"; or set lsof_bin (command -s lsof)
test -n "$sample_bin"; or set sample_bin (command -s sample)
test -n "$tmux_seconds"; or set tmux_seconds 2
test -n "$lsof_seconds"; or set lsof_seconds 7
test -n "$sample_seconds"; or set sample_seconds 7
if not string match -rq '^[1-9][0-9]*$' -- "$tmux_seconds"; or test "$tmux_seconds" -gt 10
    echo 'STOP: tmux timeout must be an integer from 1 through 10.' >&2
    exit 64
end
if not string match -rq '^[1-9][0-9]*$' -- "$lsof_seconds"; or test "$lsof_seconds" -gt 30
    echo 'STOP: lsof timeout must be an integer from 1 through 30.' >&2
    exit 64
end
if not string match -rq '^[1-9][0-9]*$' -- "$sample_seconds"; or test "$sample_seconds" -gt 30
    echo 'STOP: sample timeout must be an integer from 1 through 30.' >&2
    exit 64
end
if test -z "$tmux_bin"; or not test -x "$tmux_bin"
    echo 'STOP: tmux executable is unavailable.' >&2
    exit 64
end
if test -z "$timeout_bin"; or not test -x "$timeout_bin"
    echo 'STOP: timeout or gtimeout is required.' >&2
    exit 64
end
if not test -S "$socket"
    echo "STOP: expected tmux socket is absent: $socket" >&2
    exit 1
end
function epoch_ms
    if command -sq python3
        python3 -c 'import time; print(int(time.time()*1000))'
    else
        math (date -u +%s) \* 1000
    end
end
set -l stamp (date -u +%Y%m%dT%H%M%SZ)
set -l out "$output_root/tmux-freeze-capture-$stamp-$fish_pid"
if not mkdir -p -- "$out"
    echo "STOP: cannot create evidence directory: $out" >&2
    exit 73
end
set -g capture_out "$out"
set -g capture_socket "$socket"
set -g capture_tmux_bin "$tmux_bin"
set -g capture_timeout_bin "$timeout_bin"
set -g capture_tmux_seconds "$tmux_seconds"
set -g capture_timing "$out/timing.tsv"
printf 'label\tstart_epoch_ms\tend_epoch_ms\telapsed_ms\tstatus\n' > "$capture_timing"
function record_status --argument-names label status_code started ended
    printf '%s\n' "$status_code" > "$capture_out/$label.status.txt"
    printf '%s\t%s\t%s\t%s\t%s\n' "$label" "$started" "$ended" (math "$ended - $started") "$status_code" >> "$capture_timing"
end
function run_os --argument-names label seconds
    set -e argv[1..2]
    set -l started (epoch_ms)
    env -u TMUX -u TMUX_PANE "$capture_timeout_bin" --signal=TERM --kill-after=1s "$seconds" $argv > "$capture_out/$label.stdout.txt" 2> "$capture_out/$label.stderr.txt"
    set -l status_code $status
    set -l ended (epoch_ms)
    record_status "$label" "$status_code" "$started" "$ended"
end
function run_tmux --argument-names label
    set -e argv[1]
    set -l started (epoch_ms)
    env -u TMUX -u TMUX_PANE "$capture_timeout_bin" --signal=TERM --kill-after=1s "$capture_tmux_seconds" "$capture_tmux_bin" -S "$capture_socket" $argv > "$capture_out/$label.stdout.txt" 2> "$capture_out/$label.stderr.txt"
    set -l status_code $status
    set -l ended (epoch_ms)
    record_status "$label" "$status_code" "$started" "$ended"
end
printf 'utc=%s\nsocket=%s\ntmux=%s\ntimeout=%s\ntmux_timeout_seconds=%s\nlsof_timeout_seconds=%s\nreadonly=true\n' "$stamp" "$socket" "$tmux_bin" "$timeout_bin" "$tmux_seconds" "$lsof_seconds" > "$out/manifest.txt"
if test -n "$lsof_bin"; and test -x "$lsof_bin"
    run_os socket-lsof "$lsof_seconds" "$lsof_bin" -n -a -U "$socket"
else
    printf '%s\n' 'lsof unavailable' > "$out/socket-lsof.stdout.txt"
    set -l marked (epoch_ms)
    record_status socket-lsof 127 "$marked" "$marked"
end
set -l server_pid (awk '$1 == "tmux" && $2 ~ /^[0-9]+$/ { print $2; exit }' "$out/socket-lsof.stdout.txt")
printf '%s\n' "$server_pid" > "$out/server-pid.txt"
if test -n "$server_pid"
    run_os server-ps "$tmux_seconds" ps -p "$server_pid" -o pid=,ppid=,state=,etime=,pcpu=,pmem=,command=
    if test -n "$sample_bin"; and test -x "$sample_bin"
        run_os server-sample "$sample_seconds" "$sample_bin" "$server_pid" 5 1 -mayDie
    else
        printf '%s\n' 'sample unavailable' > "$out/server-sample.stdout.txt"
        set -l marked (epoch_ms)
        record_status server-sample 127 "$marked" "$marked"
    end
else
    printf '%s\n' 'server PID unavailable from lsof' > "$out/server-ps.stdout.txt"
    printf '%s\n' 'server PID unavailable from lsof' > "$out/server-sample.stdout.txt"
    set -l marked (epoch_ms)
    record_status server-ps 127 "$marked" "$marked"
    record_status server-sample 127 "$marked" "$marked"
end
run_tmux sessions list-sessions -F '#{session_id}|#{session_name}|#{session_created}'
run_tmux panes list-panes -a -F '#{pane_id}|#{session_name}|#{window_name}|#{pane_pid}|#{pane_in_mode}|#{pane_current_command}|#{history_size}|#{pane_width}x#{pane_height}'
run_tmux clients list-clients -F '#{client_tty}|#{client_session}|#{client_width}x#{client_height}|#{client_control_mode}'
run_tmux server-options show-options -s
run_tmux server-message display-message -p '#{version}|#{socket_path}'
if test -z "$server_pid"
    run_tmux server-pid display-message -p '#{pid}'
    set server_pid (string match -r '^[0-9]+$' < "$out/server-pid.stdout.txt" | head -1)
    printf '%s\n' "$server_pid" > "$out/server-pid.txt"
end
echo "Read-only capture complete: $out"
echo 'No keys, config reload, process control, or register writes were performed.'
