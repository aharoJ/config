function trescue --description 'tmux: capture, observe, and guide loop recovery'
    if test (count $argv) -ne 0
        echo 'usage: trescue' >&2
        return 1
    end

    set -l target /private/tmp/tmux-501/default
    set -l output_root /Users/aharoj/Desktop
    set -l capture /Users/aharoj/.config/tmux/tools/tmux-freeze-capture.fish
    set -l rescue /Users/aharoj/.config/tmux/tools/tmux-loop-rescue
    set -l lab 0

    if set -q TMUX_SHORTCUTS_LAB
        if test "$TMUX_SHORTCUTS_LAB" != 1; or not set -q TMUX_SHORTCUTS_LAB_ROOT; or not set -q TMUX_SHORTCUTS_LAB_SOCKET; or not set -q TMUX_SHORTCUTS_LAB_EVIDENCE_ROOT; or not set -q TMUX_SHORTCUTS_LAB_TMUX_BIN; or not set -q TMUX_SHORTCUTS_LAB_F2
            echo 'trescue: invalid lab override' >&2
            return 1
        end
        set lab 1
        set -l lab_root (realpath -- "$TMUX_SHORTCUTS_LAB_ROOT" 2>/dev/null)
        set target (realpath -- "$TMUX_SHORTCUTS_LAB_SOCKET" 2>/dev/null)
        set output_root "$TMUX_SHORTCUTS_LAB_EVIDENCE_ROOT"
        set rescue "$TMUX_SHORTCUTS_LAB_F2"
        if test -z "$lab_root"; or test -z "$target"; or not string match -q -- "$lab_root/*" "$target"; or test "$target" = /private/tmp/tmux-501/default
            echo 'trescue: lab target is invalid' >&2
            return 1
        end
    end

    if not test -x "$capture"; or not test -x "$rescue"
        echo 'trescue: emergency tools are unavailable' >&2
        return 1
    end

    if set -q TMUX
        set -l caller_socket (string split -m1 , -- "$TMUX")[1]
        set -l caller_real (realpath -- "$caller_socket" 2>/dev/null)
        if test -z "$caller_real"
            echo 'trescue: cannot resolve the calling tmux socket' >&2
            return 1
        end
        if test -S "$target"
            set -l target_real (realpath -- "$target" 2>/dev/null)
            set -l caller_identity (stat -f '%d:%i' "$caller_real" 2>/dev/null)
            set -l target_identity (stat -f '%d:%i' "$target_real" 2>/dev/null)
            set -l timeout_bin (command -s timeout)
            test -n "$timeout_bin"; or set timeout_bin (command -s gtimeout)
            if test -z "$target_real"; or test -z "$caller_identity"; or test -z "$target_identity"; or test -z "$timeout_bin"
                echo 'trescue: caller identity cannot be established' >&2
                return 1
            end
            set -l caller_owners (env -u TMUX -u TMUX_PANE "$timeout_bin" --signal=TERM --kill-after=1s 2 lsof -n -a -U "$caller_real" | awk '$1 == "tmux" && $2 ~ /^[0-9]+$/ { print $2 }' | sort -u)
            set -l target_owners (env -u TMUX -u TMUX_PANE "$timeout_bin" --signal=TERM --kill-after=1s 2 lsof -n -a -U "$target_real" | awk '$1 == "tmux" && $2 ~ /^[0-9]+$/ { print $2 }' | sort -u)
            if test (count $caller_owners) -ne 1; or test (count $target_owners) -ne 1
                echo 'trescue: caller identity is ambiguous' >&2
                return 1
            end
            if test "$caller_identity" = "$target_identity"; or test "$caller_owners[1]" = "$target_owners[1]"
                echo 'trescue: refuse from the target tmux server' >&2
                return 1
            end
        end
    end

    set -lx TMUX_FREEZE_CAPTURE_SOCKET "$target"
    set -lx TMUX_FREEZE_CAPTURE_OUTPUT_ROOT "$output_root"
    set -l capture_output
    set -l capture_status
    if test $lab -eq 1
        set -lx TMUX_FREEZE_CAPTURE_TMUX_BIN "$TMUX_SHORTCUTS_LAB_TMUX_BIN"
        set capture_output ("$capture" 2>&1)
        set capture_status $status
    else
        set capture_output (env -u TMUX_FREEZE_CAPTURE_TMUX_BIN -u TMUX_FREEZE_CAPTURE_TIMEOUT_BIN -u TMUX_FREEZE_CAPTURE_LSOF_BIN -u TMUX_FREEZE_CAPTURE_SAMPLE_BIN -u TMUX_FREEZE_CAPTURE_TMUX_TIMEOUT_SECONDS -u TMUX_FREEZE_CAPTURE_LSOF_TIMEOUT_SECONDS -u TMUX_FREEZE_CAPTURE_SAMPLE_TIMEOUT_SECONDS TMUX_FREEZE_CAPTURE_SOCKET="$target" TMUX_FREEZE_CAPTURE_OUTPUT_ROOT="$output_root" "$capture" 2>&1)
        set capture_status $status
    end
    printf '%s\n' $capture_output
    if test $capture_status -ne 0
        echo 'trescue: fresh capture did not complete' >&2
        return $capture_status
    end
    set -l capture_lines (string match -r '^Read-only capture complete: .+$' -- $capture_output)
    if test (count $capture_lines) -ne 1
        echo 'trescue: fresh capture did not report one evidence location' >&2
        return 1
    end
    set -l capture_evidence (string replace -r '^Read-only capture complete: (.+)$' '$1' -- "$capture_lines[1]")
    if not test -d "$capture_evidence"
        echo 'trescue: fresh capture evidence is unavailable' >&2
        return 1
    end

    set -l timeout_bin (command -s timeout)
    test -n "$timeout_bin"; or set timeout_bin (command -s gtimeout)
    if test -z "$timeout_bin"
        echo 'trescue: timeout is unavailable' >&2
        return 1
    end
    set -l target_identity (stat -f '%d:%i' "$target" 2>/dev/null)
    set -l owners (env -u TMUX -u TMUX_PANE "$timeout_bin" --signal=TERM --kill-after=1s 2 lsof -n -a -U "$target" | awk '$1 == "tmux" && $2 ~ /^[0-9]+$/ { print $2 }' | sort -u)
    if test -z "$target_identity"; or test (count $owners) -ne 1
        echo 'trescue: target owner is unavailable or ambiguous' >&2
        return 1
    end
    set -l server_pid "$owners[1]"

    set -l observe_output
    set -l observe_status
    if test $lab -eq 1
        set observe_output (env -u TMUX_LOOP_RESCUE_COUNT -u TMUX_LOOP_RESCUE_OBSERVATION -u TMUX_LOOP_RESCUE_OBSERVATION_NONCE -u TMUX_LOOP_RESCUE_LAB_HOLD_STOPPED TMUX_LOOP_RESCUE_LAB=1 TMUX_LOOP_RESCUE_LAB_ROOT="$TMUX_SHORTCUTS_LAB_ROOT" TMUX_LOOP_RESCUE_SOCKET="$target" TMUX_LOOP_RESCUE_PID="$server_pid" TMUX_LOOP_RESCUE_EVIDENCE_ROOT="$output_root" "$rescue" --observe 2>&1)
        set observe_status $status
    else
        set observe_output (env -u TMUX_LOOP_RESCUE_LAB -u TMUX_LOOP_RESCUE_LAB_ROOT -u TMUX_LOOP_RESCUE_TMUX_BIN -u TMUX_LOOP_RESCUE_TIMEOUT_BIN -u TMUX_LOOP_RESCUE_LSOF_BIN -u TMUX_LOOP_RESCUE_SAMPLE_BIN -u TMUX_LOOP_RESCUE_OBJDUMP_BIN -u TMUX_LOOP_RESCUE_SHASUM_BIN -u TMUX_LOOP_RESCUE_DWARFDUMP_BIN -u TMUX_LOOP_RESCUE_LLDB_BIN -u TMUX_LOOP_RESCUE_TMUX_TIMEOUT_SECONDS -u TMUX_LOOP_RESCUE_OBSERVATION_MAX_AGE_SECONDS -u TMUX_LOOP_RESCUE_EXPECTED_EXE -u TMUX_LOOP_RESCUE_EXPECTED_SHA256 -u TMUX_LOOP_RESCUE_EXPECTED_UUID -u TMUX_LOOP_RESCUE_EXPECTED_FRAME -u TMUX_LOOP_RESCUE_EXPECTED_FUNCTION -u TMUX_LOOP_RESCUE_EXPECTED_PC_OFFSET -u TMUX_LOOP_RESCUE_EXPECTED_INSTRUCTION_BYTES -u TMUX_LOOP_RESCUE_COUNT -u TMUX_LOOP_RESCUE_OBSERVATION -u TMUX_LOOP_RESCUE_OBSERVATION_NONCE -u TMUX_LOOP_RESCUE_PANE TMUX_LOOP_RESCUE_PRODUCTION_ACK=I-ACK-PRODUCTION-ATTACH TMUX_LOOP_RESCUE_SOCKET="$target" TMUX_LOOP_RESCUE_PID="$server_pid" TMUX_LOOP_RESCUE_EVIDENCE_ROOT="$output_root" "$rescue" --production --observe 2>&1)
        set observe_status $status
    end
    printf '%s\n' $observe_output
    if test $observe_status -ne 0
        echo 'trescue: fresh observation did not pass' >&2
        return $observe_status
    end
    set -l observe_lines (string match -r '^OBSERVE: PASS;.*$' -- $observe_output)
    if test (count $observe_lines) -ne 1
        echo 'trescue: observation did not report one result' >&2
        return 1
    end
    set -l observe_line "$observe_lines[1]"
    set -l observation (string replace -r '^.*; observation=([^;]+);.*$' '$1' -- "$observe_line")
    set -l nonce (string replace -r '^.*; nonce=([^;]+);.*$' '$1' -- "$observe_line")
    set -l observed_pid (string replace -r '^.*; server_pid=([^;]+);.*$' '$1' -- "$observe_line")
    set -l observed_identity (string replace -r '^.*; socket_identity=([^;]+);.*$' '$1' -- "$observe_line")
    set -l observed_executable (string replace -r '^.*; executable=([^;]+);.*$' '$1' -- "$observe_line")
    set -l observed_sha (string replace -r '^.*; sha256=([^;]+);.*$' '$1' -- "$observe_line")
    set -l observed_uuid (string replace -r '^.*; uuid=([^;]+);.*$' '$1' -- "$observe_line")
    set -l observed_count (string replace -r '^.*; observed_count=([0-9]+)$' '$1' -- "$observe_line")
    if not test -f "$observation"; or not string match -rq '^[A-Za-z0-9._-]+$' -- "$nonce"; or test "$observed_pid" != "$server_pid"; or test "$observed_identity" != "$target_identity"; or not string match -rq '^[1-9][0-9]*$' -- "$observed_count"
        echo 'trescue: observation identity is incomplete or changed' >&2
        return 1
    end

    printf 'Observed server: %s\n' "$observed_pid"
    printf 'Observed build: %s %s %s\n' "$observed_executable" "$observed_sha" "$observed_uuid"
    printf 'Observed count: %s\n' "$observed_count"
    printf 'Capture evidence: %s\n' "$capture_evidence"
    printf 'Observation evidence: %s\n' "$observation"
    echo 'No register write has been attempted; debugger observation may have briefly paused tmux.'
    read -P "Type RESCUE to continue to the tool's typed-PID confirmation: " continuation
    if test $status -ne 0; or test "$continuation" != RESCUE
        echo 'trescue: cancelled; no debugger write was attempted' >&2
        return 1
    end

    if set -q TMUX
        set -l caller_socket (string split -m1 , -- "$TMUX")[1]
        set -l caller_real (realpath -- "$caller_socket" 2>/dev/null)
        if test -z "$caller_real"
            echo 'trescue: caller identity changed' >&2
            return 1
        end
        if test -S "$target"
            set -l target_real (realpath -- "$target" 2>/dev/null)
            set -l caller_identity (stat -f '%d:%i' "$caller_real" 2>/dev/null)
            set -l caller_owners (env -u TMUX -u TMUX_PANE "$timeout_bin" --signal=TERM --kill-after=1s 2 lsof -n -a -U "$caller_real" | awk '$1 == "tmux" && $2 ~ /^[0-9]+$/ { print $2 }' | sort -u)
            set -l target_owners (env -u TMUX -u TMUX_PANE "$timeout_bin" --signal=TERM --kill-after=1s 2 lsof -n -a -U "$target_real" | awk '$1 == "tmux" && $2 ~ /^[0-9]+$/ { print $2 }' | sort -u)
            if test -z "$target_real"; or test -z "$caller_identity"; or test (count $caller_owners) -ne 1; or test (count $target_owners) -ne 1; or test "$caller_identity" = "$target_identity"; or test "$caller_owners[1]" = "$target_owners[1]"
                echo 'trescue: caller identity changed' >&2
                return 1
            end
        end
    end

    set -l final_identity (stat -f '%d:%i' "$target" 2>/dev/null)
    set -l final_owners (env -u TMUX -u TMUX_PANE "$timeout_bin" --signal=TERM --kill-after=1s 2 lsof -n -a -U "$target" | awk '$1 == "tmux" && $2 ~ /^[0-9]+$/ { print $2 }' | sort -u)
    if test "$final_identity" != "$target_identity"; or test (count $final_owners) -ne 1; or test "$final_owners[1]" != "$server_pid"
        echo 'trescue: target identity changed after observation' >&2
        return 1
    end

    if test $lab -eq 1
        env TMUX_LOOP_RESCUE_LAB=1 TMUX_LOOP_RESCUE_LAB_ROOT="$TMUX_SHORTCUTS_LAB_ROOT" TMUX_LOOP_RESCUE_SOCKET="$target" TMUX_LOOP_RESCUE_PID="$server_pid" TMUX_LOOP_RESCUE_COUNT="$observed_count" TMUX_LOOP_RESCUE_OBSERVATION="$observation" TMUX_LOOP_RESCUE_OBSERVATION_NONCE="$nonce" TMUX_LOOP_RESCUE_EVIDENCE_ROOT="$output_root" "$rescue"
    else
        env -u TMUX_LOOP_RESCUE_LAB -u TMUX_LOOP_RESCUE_LAB_ROOT -u TMUX_LOOP_RESCUE_TMUX_BIN -u TMUX_LOOP_RESCUE_TIMEOUT_BIN -u TMUX_LOOP_RESCUE_LSOF_BIN -u TMUX_LOOP_RESCUE_SAMPLE_BIN -u TMUX_LOOP_RESCUE_OBJDUMP_BIN -u TMUX_LOOP_RESCUE_SHASUM_BIN -u TMUX_LOOP_RESCUE_DWARFDUMP_BIN -u TMUX_LOOP_RESCUE_LLDB_BIN -u TMUX_LOOP_RESCUE_TMUX_TIMEOUT_SECONDS -u TMUX_LOOP_RESCUE_OBSERVATION_MAX_AGE_SECONDS -u TMUX_LOOP_RESCUE_EXPECTED_EXE -u TMUX_LOOP_RESCUE_EXPECTED_SHA256 -u TMUX_LOOP_RESCUE_EXPECTED_UUID -u TMUX_LOOP_RESCUE_EXPECTED_FRAME -u TMUX_LOOP_RESCUE_EXPECTED_FUNCTION -u TMUX_LOOP_RESCUE_EXPECTED_PC_OFFSET -u TMUX_LOOP_RESCUE_EXPECTED_INSTRUCTION_BYTES -u TMUX_LOOP_RESCUE_PANE TMUX_LOOP_RESCUE_PRODUCTION_ACK=I-ACK-PRODUCTION-ATTACH TMUX_LOOP_RESCUE_SOCKET="$target" TMUX_LOOP_RESCUE_PID="$server_pid" TMUX_LOOP_RESCUE_COUNT="$observed_count" TMUX_LOOP_RESCUE_OBSERVATION="$observation" TMUX_LOOP_RESCUE_OBSERVATION_NONCE="$nonce" TMUX_LOOP_RESCUE_EVIDENCE_ROOT="$output_root" "$rescue" --production
    end
end
