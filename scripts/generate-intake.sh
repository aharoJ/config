#!/usr/bin/env bash
# path: scripts/generate-intake.sh
# ───────────────────────────────────────────────────────────────
# generate-intake.sh — Assemble an LLM review intake prompt from
# a template + current source files.
#
# Usage:
#   ./scripts/generate-intake.sh <template-name>
#
# Examples:
#   ./scripts/generate-intake.sh tree-sitter-audit
#   ./scripts/generate-intake.sh tree-sitter-audit > docs/prompts/llm.intake.tree-sitter-audit.md
#
# Templates live at scripts/templates/<template-name>.md
# and use {{FILE:path/relative/to/repo}} markers that get replaced
# with the file contents wrapped in a code block.
#
# Ported from stage project (github.com/aharoJ/stage).
# ───────────────────────────────────────────────────────────────
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <template-name>" >&2
  echo "Example: $0 tree-sitter-audit" >&2
  exit 1
fi

TEMPLATE_NAME="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$SCRIPT_DIR/templates/${TEMPLATE_NAME}.md"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Error: Template not found at $TEMPLATE" >&2
  echo "Available templates:" >&2
  ls "$SCRIPT_DIR/templates/"*.md 2>/dev/null | while read f; do
    basename "$f" .md >&2
  done
  exit 1
fi

# Read template line by line and replace {{FILE:...}} markers
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^\{\{FILE:(.+)\}\}$ ]]; then
    filepath="${BASH_REMATCH[1]}"
    fullpath="$ROOT_DIR/$filepath"

    if [[ ! -f "$fullpath" ]]; then
      echo "Error: Source file not found: $fullpath" >&2
      exit 1
    fi

    # Detect language from extension
    ext="${filepath##*.}"
    case "$ext" in
      py)   lang="python" ;;
      js)   lang="javascript" ;;
      jsx)  lang="jsx" ;;
      ts)   lang="typescript" ;;
      tsx)  lang="tsx" ;;
      go)   lang="go" ;;
      rs)   lang="rust" ;;
      rb)   lang="ruby" ;;
      java) lang="java" ;;
      c)    lang="c" ;;
      cpp)  lang="cpp" ;;
      h)    lang="c" ;;
      hpp)  lang="cpp" ;;
      cs)   lang="csharp" ;;
      sql)  lang="sql" ;;
      yml)  lang="yaml" ;;
      yaml) lang="yaml" ;;
      toml) lang="toml" ;;
      md)   lang="markdown" ;;
      sh)   lang="bash" ;;
      bash) lang="bash" ;;
      *)    lang="" ;;
    esac

    # Output as markdown code block with file path header
    echo "### \`${filepath}\`"
    echo ""
    echo "\`\`\`${lang}"
    cat "$fullpath"
    echo "\`\`\`"
    echo ""
  else
    echo "$line"
  fi
done < "$TEMPLATE"
