# path: ~/.config/fish/internal/notes/calibrate/ncalibrate.fish
# description: Metacognitive calibration. Predict how much you know about a topic,
#              state your confidence, then test yourself and compare prediction to reality.
#              Distinct from nrecall (which tests knowledge) — ncalibrate tests your
#              AWARENESS of your knowledge. The prediction step catches the illusion of knowing.
# science: Koriat (1997, 1998) illusion of knowing — fluency biases confidence upward,
#          Dunning & Kruger (1999) miscalibration is worst for low-performing individuals,
#          Carpenter et al. (2022) metacognitive monitoring improves study decisions
# patched: 2026-02-26
#   - fix: {$time_stamp} brace-delimited (Claude audit)
#   - fix: uses __notes_slug for safe filenames (ChatGPT audit)
# date: 2026-02-26
function ncalibrate --description "notes: metacognitive calibration (predict → test → compare)"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: ncalibrate <topic>"
        echo ""
        echo "Predict how much you know BEFORE testing yourself."
        echo "The gap between prediction and reality is the learning signal."
        return 1
    end

    set -l slug (__notes_slug $argv)
    set -l day (date +%Y-%m-%d)
    set -l time_stamp (date +%H:%M)
    set -l dir "$NOTES_DIR/learning/calibrate"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Calibrate: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day at {$time_stamp}_" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Step 1: PREDICT (before testing)" >>"$file"
        echo "<!-- Fill this in BEFORE you test yourself. -->" >>"$file"
        echo "" >>"$file"
        echo "How many key facts/concepts can I recall about this topic?" >>"$file"
        echo "" >>"$file"
        echo "Predicted count: ___" >>"$file"
        echo "" >>"$file"
        echo "Confidence: ___% (0-100)" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Step 2: TEST (write from memory)" >>"$file"
        echo "<!-- Now list everything you actually know. No looking. -->" >>"$file"
        echo "" >>"$file"
        echo "1. " >>"$file"
        echo "2. " >>"$file"
        echo "3. " >>"$file"
        echo "4. " >>"$file"
        echo "5. " >>"$file"
        echo "" >>"$file"
        echo "Actual count: ___" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Step 3: COMPARE" >>"$file"
        echo "" >>"$file"
        echo "Delta (predicted - actual): ___" >>"$file"
        echo "" >>"$file"
        echo "### If positive (overconfident):" >>"$file"
        echo "<!-- Fluency fooled you. The material FELT familiar but wasn't retained. -->" >>"$file"
        echo "<!-- This is the #1 study trap — mistaking recognition for recall. -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### If negative (underconfident):" >>"$file"
        echo "<!-- You know more than you think. Your anxiety outpaces your gaps. -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### If zero (well-calibrated):" >>"$file"
        echo "<!-- Your self-model is accurate. This is the goal. -->" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "## What does this tell me about how I should study this topic?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
    end

    echo "=== METACOGNITIVE CALIBRATION ==="
    echo ""
    echo "  Topic: $argv"
    echo ""
    echo "  Step 1: PREDICT — how many facts can you recall? How confident?"
    echo "  Step 2: TEST — write everything from memory."
    echo "  Step 3: COMPARE — prediction vs. reality."
    echo ""
    echo "  The delta is the learning signal."
    echo "  Overconfident = fluency fooled you."
    echo "  Underconfident = anxiety outpaces your gaps."
    echo ""

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
