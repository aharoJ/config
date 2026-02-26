# path: ~/.config/fish/internal/notes/naudit.fish
# description: Run security audit on notes repo.
# date: 2026-02-24
function naudit --description "notes: security audit"
    cd "$NOTES_DIR"; or return 1

    echo "Scanning git history for sensitive patterns..."
    set -l hits (git log -p 2>/dev/null | grep -iE \
        "password\s*[:=]|api_key\s*[:=]|AKIA[0-9A-Z]{16}|BEGIN RSA|BEGIN OPENSSH|ghp_[a-zA-Z0-9]{36}|sk-[a-zA-Z0-9]{48}" \
        | head -10)

    if test -n "$hits"
        echo "ALERT: Potential sensitive data in history:"
        echo "$hits"
    else
        echo "Clean. No sensitive patterns found."
    end

    echo ""
    echo "Checking secret/ is properly ignored..."
    if git ls-files --cached | grep -E '^secret/' | grep -vq '\.gitkeep$'
        echo "WARNING: Files in secret/ are being tracked!"
    else
        echo "Good. secret/ is not tracked."
    end
end
