#!/usr/bin/env python3
# path: ~/.config/tmux/tests/codex-footer-compat-regression.py
# description: Replay accepted Codex captures against the pre-regression send policy.
# patched: protect established footer compatibility and the verbatim INFRA status tails
# date: 2026-10-02
import hashlib
import json
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
current = (root / 'tools/codex-send-to').read_text()
body = lambda source: source.split('require_empty_codex_input() {', 1)[1].split('\nsource ', 1)[0]
assert hashlib.sha256(body(current).encode()).hexdigest() == 'ed7156e464300a6af30e8a0665d8aa8c1f7d58c5ba668f98a760ddd6305940d2', 'send composer function changed'
assert 'codex-new-guard' not in current, 'reset footer grammar must not gate normal sends'
assert hashlib.sha256((root / 'tools/relay-input-guard').read_bytes()).hexdigest() == 'c0768be6a484506ed9ace4275bbf497a704220a7e7cc4d93305e14806550180a', 'baseline composer grammar changed'
checks = 0
for file in sorted((root / 'tests/fixtures').glob('*.json')):
    document = json.loads(file.read_text())
    cases = document.get('cases', []) if isinstance(document, dict) else []
    for case in cases:
        if not isinstance(case, dict) or case.get('input_exit') != 0:
            continue
        capture = case.get('capture')
        if capture is None and case.get('capture_file'):
            capture = (file.parent / case['capture_file']).read_text()
        if capture is None or case.get('glyph', '›') != '›' or '›' not in capture:
            continue
        command = [str(root / 'tools/relay-input-guard'), '›', str(case['cursor_x']), str(case['cursor_y'])]
        command += [str(case.get('pane_width', case.get('width', 167))), case.get('sender_tier', 'strict')]
        result = subprocess.run(command, input=capture, text=True, capture_output=True)
        assert result.returncode == 0, (file.name, case['name'], result.stderr)
        checks += 1
infra = json.loads((root / 'tests/fixtures/codex-infra-footer-must-accept.json').read_text())['cases']
for case in infra:
    expected = case['footer'].split(' · Context ')[0]
    for cwd in ('~/.repository/infra', '~/desk', '/Users/tester/.repository/infra'):
        capture = case['capture'].replace('~/.repository/infra', cwd)
        footer = expected.replace('~/.repository/infra', cwd)
        result = subprocess.run([str(root / 'tools/codex-new-guard'), 'footer'], input=capture, text=True, capture_output=True)
        assert result.returncode == 0 and result.stdout.strip() == footer
        fresh = re.sub('Context [0-9]+%', 'Context 0%', capture)
        assert subprocess.run([str(root / 'tools/codex-new-guard'), 'fresh', footer], input=fresh, text=True, capture_output=True).returncode == 0
        for bad in (fresh.replace('Main [default]', 'Main [other]'), fresh + fresh, fresh.replace('← for agents', '← unknown')):
            assert subprocess.run([str(root / 'tools/codex-new-guard'), 'fresh', footer], input=bad, text=True, capture_output=True).returncode == 1
        checks += 5
assert checks >= 50, checks
print(f'Codex footer compatibility: {checks} checks PASS; footer/composer grammar matches pinned baseline digests')
