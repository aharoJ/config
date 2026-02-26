# path: ~/.config/fish/internal/notes/infrastructure/__notes_slug.fish
# description: Shared slug helper. Normalizes arbitrary topic strings into safe filenames.
#              Handles spaces, slashes, colons, ampersands, punctuation, repeated separators,
#              and leading/trailing hyphens. Every function that creates files from user input
#              should use this instead of inline `string replace -a ' ' '-'`.
# fixes: ChatGPT audit — "slug generation is too weak"
# date: 2026-02-26
function __notes_slug
    # WHY: join all args into one string first (user may pass multi-word topic)
    set -l raw (string join ' ' $argv)

    # WHY: lowercase first — all slug operations work on lowercase
    set -l slug (string lower "$raw")

    # WHY: replace common separators and unsafe chars with hyphens
    # slashes would create nested directories, colons are illegal on some FS
    set slug (string replace -ra '[/\\:&@#!?*|<>\"'\''\(\)\[\]\{\}=+%\$\^~`]' '-' "$slug")

    # WHY: replace whitespace (spaces, tabs) with hyphens
    set slug (string replace -ra '\s+' '-' "$slug")

    # WHY: collapse repeated hyphens into one
    set slug (string replace -ra '-{2,}' '-' "$slug")

    # WHY: strip leading and trailing hyphens
    set slug (string replace -r '^-+' '' "$slug")
    set slug (string replace -r '-+$' '' "$slug")

    # WHY: if somehow empty after sanitization, fallback
    if test -z "$slug"
        set slug "untitled"
    end

    echo "$slug"
end
