# path: ~/.config/fish/internal/notes/ncalibrate.fish
# description: Predict-then-verify metacognitive calibration loop.
# science: Koriat (1998) illusion of knowing, Dunning-Kruger metacognitive component,
#          Carpenter et al. (2022) metacognition and strategy use
# date: 2026-02-24
function ncalibrate --description "notes: metacognitive calibration"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage:"
        echo "  ncalibrate test <topic>   - predict then test yourself"
        echo "  ncalibrate log            - view calibration history"
        return 1
    end

    set -l cmd $argv[1]
    set -l cal_dir "$NOTES_DIR/learning/calibration"
    set -l cal_log "$cal_dir/calibration-log.md"
    mkdir -p "$cal_dir"

    switch $cmd
        case test
            if test (count $argv) -lt 2
                echo "Usage: ncalibrate test <topic>"
                return 1
            end

            set -l topic (string join ' ' $argv[2..-1])
            set -l day (date +%Y-%m-%d)
            set -l time_stamp (date +%H:%M)

            echo "=== CALIBRATION TEST: $topic ==="
            echo ""
            echo "BEFORE testing yourself, predict your performance."
            echo ""
            echo "How many key facts/concepts can you recall about '$topic'?"
            read -P "  Predicted count [number]: " -l predicted
            echo ""
            echo "How confident are you in your understanding? (0-100%)"
            read -P "  Confidence: " -l confidence
            echo ""
            echo "Now write everything you know. Be specific."
            echo "When done, count your accurate items."
            echo ""
            read -P "  Press Enter to open scratch note... "

            set -l slug (string replace -a ' ' '-' (string lower "$topic"))
            set -l scratch "$cal_dir/$day-calibrate-$slug.md"
            if not test -f "$scratch"
                echo "# Calibration: $topic" >"$scratch"
                echo "" >>"$scratch"
                echo "_Date: $day at $time_stamp_" >>"$scratch"
                echo "_Predicted: $predicted items at $confidence% confidence_" >>"$scratch"
                echo "" >>"$scratch"
                echo "## Brain dump (write everything, no peeking)" >>"$scratch"
                echo "" >>"$scratch"
                echo "## After checking: how many were correct?" >>"$scratch"
                echo "" >>"$scratch"
                echo "Actual correct: " >>"$scratch"
                echo "" >>"$scratch"
                echo "## What did fluency trick me about?" >>"$scratch"
                echo "<!-- Things that FELT familiar but I could not actually retrieve -->" >>"$scratch"
                echo "" >>"$scratch"
            end

            $EDITOR "$scratch"

            echo ""
            read -P "  Actual correct count: " -l actual

            if test -n "$predicted" -a -n "$actual" -a -n "$confidence"
                set -l diff (math "$actual - $predicted")
                set -l label "calibrated"
                if test $diff -gt 0
                    set label "UNDERCONFIDENT (you knew more than you thought)"
                else if test $diff -lt 0
                    set label "OVERCONFIDENT (illusion of knowing)"
                end

                if not test -f "$cal_log"
                    echo "# Calibration Log" >"$cal_log"
                    echo "" >>"$cal_log"
                    echo "| Date | Topic | Predicted | Actual | Confidence | Result |" >>"$cal_log"
                    echo "|------|-------|-----------|--------|------------|--------|" >>"$cal_log"
                end

                echo "| $day | $topic | $predicted | $actual | $confidence% | $label |" >>"$cal_log"

                echo ""
                echo "=== RESULT: $label ==="
                echo "  Predicted: $predicted  Actual: $actual  (delta: $diff)"
                echo "  Confidence: $confidence%"

                if test $diff -lt 0
                    echo ""
                    echo "  WARNING: Fluency fooled you."
                    echo "  The material felt familiar but you could not retrieve it."
                    echo "  This is the #1 reason people overstudy easy material"
                    echo "  and understudy hard material."
                end
            end

        case log
            if test -f "$cal_log"
                cat "$cal_log"
            else
                echo "No calibration data yet. Run: ncalibrate test <topic>"
            end

        case '*'
            echo "Unknown command: $cmd"
            return 1
    end
end
