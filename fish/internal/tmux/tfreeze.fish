function tfreeze --description 'tmux: capture frozen production server'
    if test (count $argv) -ne 0
        echo 'usage: tfreeze' >&2
        return 1
    end

    set -l target /private/tmp/tmux-501/default
    set -l output_root /Users/aharoj/Desktop
    set -l capture /Users/aharoj/.config/tmux/tools/tmux-freeze-capture.fish
    set -l lab 0

    if set -q TMUX_SHORTCUTS_LAB
        if test "$TMUX_SHORTCUTS_LAB" != 1; or not set -q TMUX_SHORTCUTS_LAB_ROOT; or not set -q TMUX_SHORTCUTS_LAB_SOCKET; or not set -q TMUX_SHORTCUTS_LAB_EVIDENCE_ROOT; or not set -q TMUX_SHORTCUTS_LAB_TMUX_BIN
            echo 'tfreeze: invalid lab override' >&2
            return 1
        end
        set lab 1
        set -l lab_root (realpath -- "$TMUX_SHORTCUTS_LAB_ROOT" 2>/dev/null)
        set target (realpath -- "$TMUX_SHORTCUTS_LAB_SOCKET" 2>/dev/null)
        set output_root "$TMUX_SHORTCUTS_LAB_EVIDENCE_ROOT"
        if test -z "$lab_root"; or test -z "$target"; or not string match -q -- "$lab_root/*" "$target"; or test "$target" = /private/tmp/tmux-501/default
            echo 'tfreeze: lab target is invalid' >&2
            return 1
        end
    end

    if not test -x "$capture"
        echo "tfreeze: capture tool is unavailable: $capture" >&2
        return 1
    end

    if set -q TMUX
        set -l caller_socket (string split -m1 , -- "$TMUX")[1]
        set -l caller_real (realpath -- "$caller_socket" 2>/dev/null)
        if test -z "$caller_real"
            echo 'tfreeze: cannot resolve the calling tmux socket' >&2
            return 1
        end
        if test -S "$target"
            set -l target_real (realpath -- "$target" 2>/dev/null)
            set -l caller_identity (stat -f '%d:%i' "$caller_real" 2>/dev/null)
            set -l target_identity (stat -f '%d:%i' "$target_real" 2>/dev/null)
            set -l timeout_bin (command -s timeout)
            test -n "$timeout_bin"; or set timeout_bin (command -s gtimeout)
            if test -z "$target_real"; or test -z "$caller_identity"; or test -z "$target_identity"; or test -z "$timeout_bin"
                echo 'tfreeze: caller identity cannot be established' >&2
                return 1
            end
            set -l caller_owners (env -u TMUX -u TMUX_PANE "$timeout_bin" --signal=TERM --kill-after=1s 2 lsof -n -a -U "$caller_real" | awk '$1 == "tmux" && $2 ~ /^[0-9]+$/ { print $2 }' | sort -u)
            set -l target_owners (env -u TMUX -u TMUX_PANE "$timeout_bin" --signal=TERM --kill-after=1s 2 lsof -n -a -U "$target_real" | awk '$1 == "tmux" && $2 ~ /^[0-9]+$/ { print $2 }' | sort -u)
            if test (count $caller_owners) -ne 1; or test (count $target_owners) -ne 1
                echo 'tfreeze: caller identity is ambiguous' >&2
                return 1
            end
            if test "$caller_identity" = "$target_identity"; or test "$caller_owners[1]" = "$target_owners[1]"
                echo 'tfreeze: refuse from the target tmux server' >&2
                return 1
            end
        end
    end

    set -lx TMUX_FREEZE_CAPTURE_SOCKET "$target"
    set -lx TMUX_FREEZE_CAPTURE_OUTPUT_ROOT "$output_root"
    if test $lab -eq 1
        set -lx TMUX_FREEZE_CAPTURE_TMUX_BIN "$TMUX_SHORTCUTS_LAB_TMUX_BIN"
        "$capture"
    else
        env -u TMUX_FREEZE_CAPTURE_TMUX_BIN -u TMUX_FREEZE_CAPTURE_TIMEOUT_BIN -u TMUX_FREEZE_CAPTURE_LSOF_BIN -u TMUX_FREEZE_CAPTURE_SAMPLE_BIN -u TMUX_FREEZE_CAPTURE_TMUX_TIMEOUT_SECONDS -u TMUX_FREEZE_CAPTURE_LSOF_TIMEOUT_SECONDS -u TMUX_FREEZE_CAPTURE_SAMPLE_TIMEOUT_SECONDS TMUX_FREEZE_CAPTURE_SOCKET="$target" TMUX_FREEZE_CAPTURE_OUTPUT_ROOT="$output_root" "$capture"
    end
end
