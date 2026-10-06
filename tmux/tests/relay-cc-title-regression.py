#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
output = Path(sys.argv[1])
output.mkdir(parents=True, exist_ok=True)
manifest = root / 'tests/fixtures/relay-cc-title-real.json'
checks = 0
for case in json.loads(manifest.read_text())['cases']:
    capture = (manifest.parent / case['capture_file']).read_bytes()
    metadata = (manifest.parent / case['meta_file']).read_bytes()
    assert hashlib.sha256(capture).hexdigest() == case['capture_sha256']
    assert hashlib.sha256(metadata).hexdigest() == case['meta_sha256']
    meta = json.loads(metadata)
    assert meta['capture_origin'].startswith('real')
    x, y, width = meta['cursor_x'], meta['cursor_y'], meta['pane_width']
    if 'expected_input' in meta:
        result = subprocess.run([str(root / 'tools/relay-input-guard'), '❯', str(x), str(y), str(width)], input=capture, capture_output=True)
        assert result.returncode == meta['expected_input'], (case['name'], result.stderr)
        checks += 1
        continue
    payload = output / (case['name'] + '.payload')
    payload.write_text(meta['expected_payload'])
    def check(raw, cursor_x=x, cursor_y=y, pane_width=width, expected=1):
        global checks
        result = subprocess.run([str(root / 'tools/relay-payload-guard'), 'compare', '❯', str(cursor_x), str(cursor_y), str(payload), str(pane_width)], input=raw, capture_output=True)
        assert result.returncode == expected, (case['name'], result.returncode, result.stderr)
        checks += 1
    check(capture, expected=0)
    check(capture, cursor_x=2)
    check(capture, pane_width=width-1)
    rows = capture.decode().splitlines()
    changed = list(rows)
    changed[y] += 'human draft'
    check(('\n'.join(changed)+'\n').encode())
    changed = list(rows)
    changed.insert(y+1, '  another input line')
    check(('\n'.join(changed)+'\n').encode())
    changed = list(rows)
    changed[y+1] = changed[y-1]
    check(('\n'.join(changed)+'\n').encode())
    changed = list(rows)
    changed[y-1] = changed[y-1][1:]
    check(('\n'.join(changed)+'\n').encode())
print(f'PASS: {checks} real-capture and explicitly derived negative checks')
