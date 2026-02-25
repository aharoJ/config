# path: ~/.config/fish/internal/notes/nrate.fish
# description: Rate recall and update next_review + last_rating in YAML frontmatter.
#              Simple SM-2-inspired adaptive spacing: review frequency follows recall quality.
# science: Wozniak SM-2 algorithm, Cepeda (2008) optimal spacing depends on retention
# date: 2026-02-24
#
# Intervals:
#   again (1) = 1 day   - blanked, see it tomorrow
#   hard  (2) = 3 days  - shaky, needs reinforcement soon
#   good  (3) = 7 days  - solid recall, standard interval
#   easy  (4) = 21 days - effortless, push it out further
function nrate --description "notes: rate recall and schedule next review"
    __notes_require; or return 1

    if test (count $argv) -lt 1
        echo "Usage: nrate <file-or-search-term>"
        return 1
    end

    set -l term (string join ' ' $argv)
    set -l target ""

    if test -f "$NOTES_DIR/$term"
        set target "$NOTES_DIR/$term"
    else if test -f "$term"
        set target "$term"
    else
        set -l found (cd "$NOTES_DIR"; and find . -iname "*$term*" -name "*.md" \
            -not -path '*/.git/*' -not -path '*/secret/*' | head -1)
        if test -n "$found"
            set target "$NOTES_DIR/"(string replace './' '' -- "$found")
        end
    end

    if test -z "$target"; or not test -f "$target"
        echo "No note found matching: $term"
        return 1
    end

    set -l relative (string replace "$NOTES_DIR/" "" -- "$target")
    echo "Rating: $relative"
    echo ""
    echo "How well did you recall this?"
    echo "  [1] again  - blanked, see it tomorrow"
    echo "  [2] hard   - shaky, 3 days"
    echo "  [3] good   - solid, 7 days"
    echo "  [4] easy   - effortless, 21 days"
    echo ""
    read -P "Choice [1-4]: " -l r

    set -l days
    set -l label
    switch $r
        case 1
            set days 1
            set label "again"
        case 2
            set days 3
            set label "hard"
        case 3
            set days 7
            set label "good"
        case 4
            set days 21
            set label "easy"
        case '*'
            echo "Invalid choice. Use 1-4."
            return 1
    end

    # Compute next review date (macOS first, then GNU fallback)
    set -l next (date -v+{$days}d +%Y-%m-%d 2>/dev/null)
    if test -z "$next"
        set next (date -d "+$days days" +%Y-%m-%d 2>/dev/null)
    end
    if test -z "$next"
        echo "Could not compute next date."
        return 1
    end

    # Require python3 or python for robust frontmatter editing
    set -l py "python3"
    if not type -q python3
        if type -q python
            set py "python"
        else
            echo "Need python3 (or python) to update frontmatter."
            return 1
        end
    end

    $py - <<PY "$target" "$next" "$label"
import sys, re

path = sys.argv[1]
next_date = sys.argv[2]
rating = sys.argv[3]

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

def upsert_frontmatter(src: str, updates: dict) -> str:
    """Insert or update key-value pairs in YAML frontmatter."""
    if src.startswith("---"):
        m = re.search(r"^---\s*\n(.*?)\n---\s*\n", src, flags=re.S)
        if m:
            fm_lines = m.group(1).splitlines()
            handled = set()
            out = []
            for line in fm_lines:
                replaced = False
                for key, value in updates.items():
                    if re.match(r"^\s*" + re.escape(key) + r"\s*:", line):
                        out.append(f"{key}: {value}")
                        handled.add(key)
                        replaced = True
                        break
                if not replaced:
                    out.append(line)
            # Append any keys that were not already present
            for key, value in updates.items():
                if key not in handled:
                    out.append(f"{key}: {value}")
            new_fm = "---\n" + "\n".join(out).rstrip() + "\n---\n"
            return new_fm + src[m.end():]
    # No frontmatter exists: prepend minimal block
    lines = []
    for key, value in updates.items():
        lines.append(f"{key}: {value}")
    return "---\n" + "\n".join(lines) + "\n---\n\n" + src

new_text = upsert_frontmatter(text, {
    "next_review": next_date,
    "last_rating": rating,
})

with open(path, "w", encoding="utf-8") as f:
    f.write(new_text)

print(next_date)
PY

    echo ""
    echo "Rated: $label"
    echo "Next review: $next (+$days days)"
end
