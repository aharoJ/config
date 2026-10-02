#!/usr/bin/env bash
# path: ~/.config/tmux/tests/relay-live-capture-regression.sh
# description: Verify proven empty composer captures and a stable current private Codex corpus.
# patched: require proven Claude, Codex, and Agy idle captures before landing
# date: 2026-10-02T04:00:00Z
set -euo pipefail

fail() { printf 'relay live capture regression: %s\n' "$1" >&2; exit 1; }
has_ansi() { printf '%s\n' "$1" | perl -ne '$found ||= /\e\[/; END { exit($found ? 0 : 1) }'; }
strip_ansi() { perl -pe 's/\e\[[0-?]*[ -\/]*[@-~]//g; s/\e\][^\e\a]*(?:\a|\e\\)//g'; }

[ "$#" = 2 ] && { [ "$1" = --manifest ] || [ "$1" = --fixtures ]; } || fail 'usage: relay-live-capture-regression.sh --fixtures <json> | --manifest <tsv>'
manifest=$2
[ -f "$manifest" ] && [ -r "$manifest" ] || fail 'manifest is not a readable regular file'

root="$(cd -P "$(dirname "$0")/.." && pwd)"
guard="$root/tools/relay-input-guard"
[ -x "$guard" ] || fail 'relay input guard is not executable'
if [ "$1" = --fixtures ]; then
  python3 - "$guard" "$manifest" <<'PY'
import hashlib
import json
import pathlib
import subprocess
import sys

guard, manifest = sys.argv[1:]
path = pathlib.Path(manifest)
cases = json.loads(path.read_text())["cases"]
required = {"fable", "deepseek", "config-claude", "astra-fresh", "astra-post-turn", "fable-fresh", "fable-post-turn", "deepseek-fresh", "deepseek-post-turn", "deepseek-idle-40", "deepseek-idle-19", "agy-fresh", "agy-post-turn", "agy-post-helper", "agy-wide-200", "agy-narrow-40", "agy-narrow-19"}
assert {case["name"] for case in cases} == required
for case in cases:
    capture = (path.parent / case["capture_file"]).read_bytes()
    meta = (path.parent / case["meta_file"]).read_bytes()
    assert hashlib.sha256(capture).hexdigest() == case["capture_sha256"], case["name"]
    assert hashlib.sha256(meta).hexdigest() == case["meta_sha256"], case["name"]
    assert pathlib.Path(case["source"]).is_absolute(), case["name"]
    assert (f'cursor={case["cursor_x"]},{case["cursor_y"]}'.encode() in meta or
            meta.split()[5:7] == [str(case["cursor_x"]).encode(), str(case["cursor_y"]).encode()]), case["name"]
    result = subprocess.run([guard, case["glyph"], str(case["cursor_x"]), str(case["cursor_y"]), str(case["pane_width"])], input=capture, capture_output=True)
    assert result.returncode == 0, (case["name"], result.returncode)
print(f"relay must-accept capture regression: {len(cases)} proven idle states, PASS")
PY
  exit $?
fi
tmux_context="$(printenv TMUX 2>/dev/null || true)"
socket="$(printf '%s\n' "$tmux_context" | sed 's/,.*//')"
server="$(basename "$socket")"
[[ "$server" =~ ^ccmsg-lab-private-[0-9]+$ ]] || fail 'an explicitly private lab TMUX context is required'
lab_tmux() { tmux -L "$server" -f /dev/null "$@"; }

awk -F '\t' '
  /^[[:space:]]*(#|$)/ { next }
  NF != 5 { exit 1 }
  $1 !~ /^[a-z0-9][a-z0-9-]*$/ { exit 1 }
  $2 !~ /^[A-Za-z0-9_.:%@=+-]+$/ { exit 1 }
  $3 !~ /^[01]$/ { exit 1 }
  $4 !~ /^[0-9]+\.[0-9]+\.[0-9]+$/ { exit 1 }
  $5 == "" { exit 1 }
  ++seen[$1] != 1 { exit 1 }
' "$manifest" || fail 'manifest must have unique name, target, expected-exit, Codex-version, and visible-marker TSV columns'

require_case() {
  local required_name=$1 required_exit=$2
  awk -F '\t' -v name="$required_name" -v expected="$required_exit" '
    $1 == name && $3 == expected { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$manifest" || fail "manifest is missing required $required_name state with expected exit $required_exit"
}
require_case fresh-empty 0
require_case post-subagent-empty 0
require_case working-empty 0
require_case single-line-draft 1
require_case multiline-draft 1
require_case home-cursor-draft 1

version_bin="$(printenv CODEX_VERSION_BIN 2>/dev/null || true)"
[ -n "$version_bin" ] || version_bin=codex
version_output="$("$version_bin" --version 2>/dev/null)" || fail 'cannot attest the installed Codex version'
codex_version="$(printf '%s\n' "$version_output" | sed -nE 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -1)"
[ -n "$codex_version" ] || fail "cannot parse Codex version: $version_output"

snapshot() {
  local name=$1 target=$2 expected=$3 marker=$4 state_before state_between state_after styled_first styled_second plain
  local pane_id pane_pid command in_mode cursor_x cursor_y width height code cursor_row previous_row

  state_before="$(lab_tmux display-message -p -t "$target" '#{pane_id}:#{pane_pid}:#{pane_current_command}:#{pane_in_mode}:#{cursor_x}:#{cursor_y}:#{pane_width}:#{pane_height}')" || fail "$name cannot query pre-capture state"
  styled_first="$(lab_tmux capture-pane -p -e -t "$target")" || fail "$name cannot take first styled capture"
  state_between="$(lab_tmux display-message -p -t "$target" '#{pane_id}:#{pane_pid}:#{pane_current_command}:#{pane_in_mode}:#{cursor_x}:#{cursor_y}:#{pane_width}:#{pane_height}')" || fail "$name cannot query middle state"
  styled_second="$(lab_tmux capture-pane -p -e -t "$target")" || fail "$name cannot take second styled capture"
  state_after="$(lab_tmux display-message -p -t "$target" '#{pane_id}:#{pane_pid}:#{pane_current_command}:#{pane_in_mode}:#{cursor_x}:#{cursor_y}:#{pane_width}:#{pane_height}')" || fail "$name cannot query post-capture state"

  [ "$state_before" = "$state_between" ] && [ "$state_before" = "$state_after" ] || fail "$name identity, cursor, or geometry changed during capture"
  [ "$styled_first" = "$styled_second" ] || fail "$name styled screen changed during capture"
  has_ansi "$styled_first" || fail "$name styled capture has no ANSI sequence"

  IFS=: read -r pane_id pane_pid command in_mode cursor_x cursor_y width height <<< "$state_before"
  [[ "$pane_id" =~ ^%[0-9]+$ && "$pane_pid" =~ ^[0-9]+$ && "$in_mode" = 0 && "$cursor_x" =~ ^[0-9]+$ && "$cursor_y" =~ ^[0-9]+$ && "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || fail "$name has an invalid normal-composer state: $state_before"
  case "$command" in codex|node|codex-cli) ;; *) fail "$name target is not a direct Codex process: $command" ;; esac

  plain="$(printf '%s\n' "$styled_first" | strip_ansi)"
  [ -n "$plain" ] || fail "$name normalized capture is empty"
  printf '%s\n' "$plain" | grep -F -q -- "$marker" || fail "$name lacks required visible marker: $marker"
  cursor_row="$(printf '%s\n' "$plain" | sed -n "$((cursor_y + 1))p")"
  previous_row=
  [ "$cursor_y" = 0 ] || previous_row="$(printf '%s\n' "$plain" | sed -n "${cursor_y}p")"
  if [ "$name" = fresh-empty ]; then
    [[ "$plain" == *"OpenAI Codex (v$codex_version)"* ]] || fail "$name does not attest Codex v$codex_version"
  fi

  # A case name is evidence, not a semantic assertion.  Require the visible
  # state it names so a cursor-only/draft-only substitute cannot make the
  # current private corpus print PASS.
  case "$name" in
    fresh-empty)
      [ "$cursor_x" = 2 ] || fail "$name must remain at the prompt column"
      ;;
    post-subagent-empty)
      [ "$cursor_x" = 2 ] || fail "$name must remain at the prompt column"
      [[ "$plain" == *"Main [default]"* ]] || fail "$name lacks the Main [default] state marker"
      ;;
    working-empty)
      [ "$cursor_x" = 2 ] || fail "$name must remain at the prompt column"
      [[ "$plain" == *"Working"* ]] || fail "$name lacks a Working state marker"
      ;;
    single-line-draft)
      [ "$cursor_x" -gt 2 ] || fail "$name is not an end-of-line draft"
      printf '%s\n' "$cursor_row" | perl -CSDA -ne 's/^\h*\x{203a}\h*//; exit(/\S/ ? 0 : 1)' || fail "$name lacks visible prompt-row text"
      ;;
    multiline-draft)
      [ "$cursor_y" -gt 0 ] || fail "$name has no continuation row"
      printf '%s\n' "$previous_row" | perl -CSDA -ne 'exit(/^\h*\x{203a}/ ? 0 : 1)' || fail "$name lacks a prompt before its continuation"
      printf '%s\n' "$cursor_row" | perl -CSDA -ne 'exit(/^\h+\S/ ? 0 : 1)' || fail "$name lacks visible continuation text"
      ;;
    home-cursor-draft)
      [ "$cursor_x" = 2 ] || fail "$name must remain at the prompt column"
      printf '%s\n' "$cursor_row" | perl -CSDA -ne 's/^\h*\x{203a}\h*//; exit(/\S/ ? 0 : 1)' || fail "$name lacks visible Home-moved draft text"
      ;;
  esac

  set +e
  printf '%s\n' "$styled_first" | "$guard" '›' "$cursor_x" "$cursor_y" >/dev/null
  code=$?
  set -e
  [ "$code" = "$expected" ] || fail "$name guard returned $code, expected $expected"
  printf 'PASS %s guard=%s pane=%s cursor=%s:%s geometry=%sx%s version=%s\n' "$name" "$code" "$pane_id" "$cursor_x" "$cursor_y" "$width" "$height" "$codex_version"
}

count=0
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
  IFS=$'\t' read -r name target expected capture_version marker extra <<< "$line"
  [ -z "$extra" ] || fail "manifest has extra columns for $name"
  [ "$capture_version" = "$codex_version" ] || fail "$name attests $capture_version, installed Codex is $codex_version"
  snapshot "$name" "$target" "$expected" "$marker"
  count=$((count + 1))
done < "$manifest"

printf 'relay live capture regression: %s stable current Codex states, PASS\n' "$count"
