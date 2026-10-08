#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
output = Path(sys.argv[1]).resolve()
assert output.is_relative_to(Path.home() / 'desk')
output.mkdir(parents=True, exist_ok=True)
control_dir = Path(tempfile.mkdtemp(prefix='rn-c-', dir=Path.home() / 'desk/lab'))
control = control_dir / 'control.sock'
subprocess.run(['tmux', '-S', str(control), '-f', '/dev/null', 'new-session', '-d', '-s', 'unrelated-control', 'exec cat'], check=True)
try:
    result = subprocess.run([sys.executable, str(ROOT / 'relay-fast-tier.py'), '--private-tmux', '--workers', '3', '--timeout', '1', '--output', str(output)], capture_output=True, text=True, timeout=15)
    (output / 'stdout.log').write_text(result.stdout)
    (output / 'stderr.log').write_text(result.stderr)
    assert result.returncode == 1, result
    receipt = json.loads((output / 'results.json').read_text())
    assert any(row['exit'] == 124 for row in receipt['results']), receipt
    assert len({row['sockets'] for row in receipt['results']}) == len(receipt['results']) == 8
    cleanups = [item for row in receipt['results'] for item in row['cleanup']]
    assert cleanups and all(item['state'] == 'stopped' for item in cleanups), receipt
    assert any(item['kill_exit'] == 0 for item in cleanups), receipt
    for item in cleanups:
        proof = subprocess.run(['tmux', '-S', item['socket'], 'list-sessions'], capture_output=True, text=True)
        assert proof.returncode == 1 and 'no server running' in proof.stderr, proof
    subprocess.run(['tmux', '-S', str(control), 'list-sessions'], check=True, capture_output=True)
    print('PASS timed-out private workers stop their own servers; distinct workers and unrelated control remain isolated')
finally:
    subprocess.run(['tmux', '-S', str(control), 'kill-server'], check=True)
