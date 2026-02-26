# path: ~/.config/fish/internal/notes/nwhy.fish
# description: Elaborative interrogation — ask WHY and HOW questions to connect new
#              knowledge to prior knowledge. Also forces falsifiable claims (absorbed
#              from ncollapse) to commit understanding into testable statements.
# science: Pressley et al. (1988) elaborative interrogation improves fact retention,
#          Dunlosky et al. (2013) rated elaborative interrogation "moderate-to-high utility",
#          Chi et al. (1989) self-explanation effect — explaining forces deeper processing
# absorbed: ncollapse.fish (falsifiable claims — same self-explanation mechanism family)
# date: 2026-02-26
function nwhy --description "notes: elaborative interrogation + falsifiable claims"
    __notes_require; or return 1

    if test (count $argv) -eq 0
        echo "Usage: nwhy <topic>"
        echo ""
        echo "Forces deep processing through WHY/HOW questions and falsifiable claims."
        echo "Two phases: interrogate (ask questions) then collapse (commit to claims)."
        return 1
    end

    set -l slug (string replace -a ' ' '-' (string lower (string join ' ' $argv)))
    set -l day (date +%Y-%m-%d)
    set -l time_stamp (date +%H:%M)
    set -l dir "$NOTES_DIR/learning/why"
    set -l file "$dir/$day-$slug.md"
    mkdir -p "$dir"

    if not test -f "$file"
        echo "# Why: $argv" >"$file"
        echo "" >>"$file"
        echo "_Date: $day at $time_stamp_" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Phase 1: Interrogate" >>"$file"
        echo "<!-- Ask WHY and HOW questions. Connect to what you already know. -->" >>"$file"
        echo "" >>"$file"
        echo "### Why does this work this way?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### How is this different from [related concept]?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### What would happen if this were NOT true?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### Where have I seen this pattern before?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### What prerequisite does this depend on?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "---" >>"$file"
        echo "" >>"$file"
        echo "## Phase 2: Collapse — falsifiable claims" >>"$file"
        echo "<!-- Turn your vague understanding into 5 SPECIFIC claims. -->" >>"$file"
        echo "<!-- Each must be WRONG-able. If it can't be wrong, it says nothing. -->" >>"$file"
        echo "" >>"$file"
        echo "1. " >>"$file"
        echo "2. " >>"$file"
        echo "3. " >>"$file"
        echo "4. " >>"$file"
        echo "5. " >>"$file"
        echo "" >>"$file"
        echo "### Which claim am I LEAST sure about? Why?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
        echo "### Which claim would be most costly to get wrong?" >>"$file"
        echo "" >>"$file"
        echo "" >>"$file"
    end

    echo "=== ELABORATIVE INTERROGATION ==="
    echo ""
    echo "  Topic: $argv"
    echo ""
    echo "  PHASE 1 — INTERROGATE:"
    echo "    Ask WHY and HOW. Connect to prior knowledge."
    echo "    If you can't answer a question, that's the gap."
    echo ""
    echo "  PHASE 2 — COLLAPSE:"
    echo "    Write 5 specific, falsifiable claims."
    echo "    If a claim can't be wrong, it says nothing."
    echo "    The claim you're least sure about is where to study next."
    echo ""

    cd "$NOTES_DIR"; and $EDITOR "$file"
end
