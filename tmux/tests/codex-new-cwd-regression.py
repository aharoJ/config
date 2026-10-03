#!/usr/bin/env python3
# path: ~/.config/tmux/tests/codex-new-cwd-regression.py
# description: Replay byte-exact sanitized Codex captures across cwd and footer variants.
# date: 2026-10-02
import hashlib
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures'
cases = json.loads((fixtures / 'codex-new-cwd-live.json').read_text())['cases']
checks = 0
for case in cases:
    raw = (fixtures / case['capture_file']).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == case['sha256'], case
    meta = (fixtures / case['meta_file']).read_bytes()
    assert hashlib.sha256(meta).hexdigest() == case['meta_sha256'], case
    fields = meta.decode().strip().split('|')
    assert tuple(map(int, fields[4:7])) == (case['cursor_x'], case['cursor_y'], case['width']), case
    assert fields[3] == case['cwd'] and fields[8] == '0', case
    assert (b'Main [default]' in raw) == case['main_default'], case
    modes = ['footer'] if case['stage'] == 'before' else ['reset', 'fresh', 'direct-reset']
    for mode in modes:
        args = [str(root / 'tools/codex-new-guard'), mode]
        if mode != 'footer':
            args.append(case['footer'])
        result = subprocess.run(args, input=raw, capture_output=True)
        assert result.returncode == 0, (case, mode, result.stderr)
        checks += 1
    args = [str(root / 'tools/relay-input-guard'), '›', str(case['cursor_x']), str(case['cursor_y']), str(case['width']), 'strict']
    result = subprocess.run(args, input=raw, capture_output=True)
    assert result.returncode == 0, (case, result.stderr)
    checks += 1
for label in ['nongit', 'git', 'config', 'another-repo']:
    assert any(c['label'] == label and not c['main_default'] for c in cases)
    assert any(c['label'] == label + '-main' and c['main_default'] for c in cases)
extra = json.loads((fixtures / 'codex-new-reset-ansi.json').read_text())['cases']
for case in extra:
    raw = (fixtures / case['capture_file']).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == case['sha256'], case
    for mode in ['reset', 'fresh', 'direct-reset']:
        result = subprocess.run([str(root / 'tools/codex-new-guard'), mode, case['footer']], input=raw, capture_output=True)
        assert result.returncode == 0, (case, mode)
        checks += 1
    result = subprocess.run([str(root / 'tools/relay-input-guard'), '›', str(case['cursor_x']), str(case['cursor_y']), str(case['width']), 'strict'], input=raw, capture_output=True)
    assert result.returncode == 0, case
    checks += 1
print(f'codex new cwd real captures: {len(cases) + len(extra)} captures; {checks} checks PASS')
