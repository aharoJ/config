#!/usr/bin/env python3
# path: ~/.config/tmux/tests/codex-new-chat-regression.py
# description: Verify menu-or-reset routing and the unchanged fresh-chat post-checks.
# date: 2026-10-02
import json
import os
import pathlib
import shlex
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
helper = (root / 'tools/codex-new-chat').read_text()
definitions = helper.split('new_observe() {', 1)[1].split('\n[ "$#" = 1 ]', 1)[0]
definitions = 'new_observe() {' + definitions
delivery = (root / 'tools/relay-delivery.sh').read_text()
busy = 'relay_busy_preflight() {' + delivery.split('relay_busy_preflight() {', 1)[1].split('\nrelay_refusal_reason()', 1)[0]
footer = 'Fast off · GPT-6.1-Sol low · ~/demo/lab/nongit'
fresh = '  >_ OpenAI Codex (v0.160.0)\n     ~/demo/lab/nongit\n  \x1b[38;2;99;168;248mHello.\x1b[39m\n  \x1b[1mTip:\x1b[0m Use /title.\n\x1b[1m›\x1b[0m \x1b[2mAsk Codex to do anything\x1b[0m\n\n  ' + footer + ' · Context 0% used\n'
menu = (root / 'tests/fixtures/codex-new-menu.ansi').read_text()
checks = 0


def check(screen, expected_code, wanted='', expected=footer, cursor_x=2, cursor_y=4):
    global checks
    directory = pathlib.Path(tempfile.mkdtemp(prefix='codex-new-chat-tests-', dir=os.environ.get('TMPDIR', pathlib.Path.home() / 'desk/lab')))
    capture = directory / 'screen.ansi'
    capture.write_text(screen)
    script = '\n'.join([
        'set -uo pipefail',
        'relay_script_dir=' + shlex.quote(str(root / 'tools')),
        'RELAY_INPUT_GUARD=' + shlex.quote(str(root / 'tools/relay-input-guard')),
        'before_footer=' + shlex.quote(expected),
        'relay_verify_width=215', 'relay_sender_tier=strict', "relay_glyph='›'", 'pane=%1',
        definitions, busy,
        'partial() { printf "%s\\n" "$1" >&2; exit 4; }',
        'refuse_draft() { exit 5; }',
        'new_observe() { new_capture="$(<' + shlex.quote(str(capture)) + ')"; }',
        'relay_display() { printf "%s\\n" ' + shlex.quote(f'{cursor_x}:{cursor_y}') + '; }',
        'sleep() { :; }',
        'new_destination_wait',
        '[ "$new_destination" != menu ] || { printf "MENU\\n"; exit 0; }',
        'if ! printf "%s\\n" "$new_capture" | "$relay_script_dir/codex-new-guard" fresh "$before_footer"; then new_idle; printf "RESTORE\\n"; exit 0; fi',
        'new_wait fresh', 'new_idle', 'printf "FRESH\\n"',
    ])
    result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
    assert result.returncode == expected_code, (screen, result.returncode, expected_code, result.stderr)
    if wanted:
        assert result.stdout.strip() == wanted, result.stdout
    assert 'send-keys' not in result.stdout
    subprocess.run(['trash', str(directory)], check=True)
    checks += 1


check(menu, 0, 'MENU')
check(fresh, 0, 'FRESH')
check(fresh.replace(' · Context ', ' · Context ').replace(' used', ' used · Main [default]'), 0, 'FRESH')
check(fresh.replace('GPT-6.1-Sol low', 'GPT-6-Astra high'), 0, 'RESTORE')
check(fresh.replace('\n\x1b[1m›', '\n• Model changed to gpt-6.1-sol low for this session only\n\x1b[1m›'), 0, 'FRESH', cursor_y=5)
for screen in [
    'unrecognized overlay\n',
    'Previous conversation remains loaded: BANANA.\n' + fresh,
    fresh.replace('\n\x1b[1m›', '\n• Model changed to gpt-6-astra high for this session only\n\x1b[1m›'),
    menu.replace('Current checkout', 'Unknown checkout'),
    fresh.replace('Context 0%', 'Context 1%'),
    fresh.replace('Context 0%', 'Context 100%'),
    fresh.replace('nongit', 'other-cwd'),
    fresh.replace('Fast off', 'Fast on'),
    fresh + fresh,
    fresh.replace('Context 0% used', 'Context 0% used unknown'),
    fresh.replace('Main [default]', 'Main [other]').replace(' used\n', ' used · Main [other]\n'),
    fresh.replace(' · Context 0% used', ''),
    fresh.replace('\x1b[2mAsk Codex to do anything\x1b[0m', 'unsent draft'),
    fresh.replace('\x1b[2mAsk Codex to do anything\x1b[0m', '/new'),
    fresh.replace('\n\n  Fast', '\n  unsent continuation\n\n  Fast'),
    fresh + 'unknown overlay\n',
    fresh.replace('Fast off', '\x1b[8mFast off\x1b[0m'),
]:
    check(screen, 4)
check('• Working (1s • esc to interrupt)\n\n' + fresh, 4, cursor_y=6)
check(fresh, 4, cursor_y=1)

startup = (root / 'tests/fixtures/codex-new-live-startup-residue.ansi').read_text()
startup_y = next(i for i, row in enumerate(startup.splitlines()) if 'Ask Codex to do anything' in row)
check(startup, 0, 'FRESH', 'Fast off · GPT-6.1-Sol low · ~/demo/lab/codex-new-chat-smoke', 2, startup_y)
check(startup.replace('\x1b[38;2;135;161;238mcodex-new-chat-smoke', ' • Working (1s • esc to interrupt) ', 1), 4, '', 'Fast off · GPT-6.1-Sol low · ~/demo/lab/codex-new-chat-smoke', 2, startup_y)

for name, mode in [('codex-new-live-busy-slash', 'busy'), ('codex-new-live-real-busy', 'busy'), ('codex-new-live-real-busy-narrow', 'busy'),
                   ('codex-new-live-real-busy-draft', 'busy'), ('codex-new-live-real-busy-slash', 'busy-slash')]:
    screen = (root / f'tests/fixtures/{name}.ansi').read_text()
    assert subprocess.run([str(root / 'tools/codex-new-guard'), mode], input=screen, text=True).returncode == 0, name
    checks += 1

manifest = root / 'tests/fixtures/codex-new-cwd-live.json'
if manifest.exists():
    for case in json.loads(manifest.read_text())['cases']:
        capture = (manifest.parent / case['capture_file']).read_text()
        if case['stage'] == 'after':
            check(capture, 0, 'FRESH', case['footer'], case['cursor_x'], case['cursor_y'])
print(f'codex new chat transition: {checks} checks PASS')
