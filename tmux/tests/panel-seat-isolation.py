#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[2]
output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
home = output / 'home'
home.mkdir()
(home / '.config').symlink_to(repo)
(home / '.claude.json').write_text('{}')
settings = home / '.gemini/antigravity-cli/settings.json'
settings.parent.mkdir(parents=True)
settings.write_text('{}')
key = home / 'desk/.secret/deepseek/api-key'
key.parent.mkdir(parents=True)
key.write_text('fixture-key-not-real-01234567890123456789')
env = dict(os.environ, HOME=str(home))
seat = Path(tempfile.mkdtemp(prefix='review-protocol-config-isolation-audit-r1-agentic-test-', suffix='-cli', dir='/private/tmp'))
peer = Path(tempfile.mkdtemp(prefix='review-protocol-config-isolation-audit-r1-agentic-peer-', suffix='-cli', dir='/private/tmp'))
rows = {}
try:
    (seat / 'intake.txt').write_text('seat input\n')
    (peer / 'private.txt').write_text('other seat\n')
    for kind in ('astra', 'fable', 'deepseek', 'gemini'):
        code = 'source ' + shlex.quote(str(repo / 'fish/internal/tmux/tai.fish')) + '; function __tai_spawn; printf "%s\\n" $argv; end; __tai_seat fixture ' + kind
        result = subprocess.run(['fish', '--no-config', '-c', code], cwd=seat, env=env, capture_output=True, text=True, timeout=15)
        assert result.returncode == 0, (kind, result.stdout, result.stderr)
        rows[kind] = result.stdout.splitlines()
        assert '--env=TMPDIR=' + str(seat / 'scratch') in rows[kind]
        assert kind == 'gemini' or not any('dangerously' in arg for arg in rows[kind])
    assert 'gpt-6-sol' in rows['astra'] and '--no-daemon' in rows['astra']
    assert 'default_permissions="panel-seat"' in rows['astra']
    assert '--setting-sources' in rows['fable'] and '--permission-mode' in rows['fable']
    assert '--env=PANEL_SEAT_CONFINED=1' in rows['deepseek'] and '--bare' in rows['deepseek']
    assert '--sandbox' in rows['gemini']
    base = 'source ' + shlex.quote(str(repo / 'fish/internal/tmux/tai.fish')) + '; function __tai_spawn; printf "%s\\n" $argv; end; __tai_seat fixture astra '
    for args, model in ((['-c', 'model_reasoning_effort="high"'], 'gpt-6-sol'), (['-m', 'gpt-6-luna'], 'gpt-6-luna')):
        result = subprocess.run(['fish', '--no-config', '-c', base + shlex.join(args)], cwd=seat, env=env, capture_output=True, text=True, timeout=15)
        assert result.returncode == 0 and model in result.stdout.splitlines(), (result.stdout, result.stderr)
    result = subprocess.run(['fish', '--no-config', '-c', base + "-c 'model=\"gpt-6-luna\"'"], cwd=seat, env=env, capture_output=True, text=True, timeout=15)
    assert result.returncode == 2 and 'could drift' in result.stderr
    policy = json.loads((seat / 'panel-settings.json').read_text())
    assert policy['sandbox']['enabled'] and policy['sandbox']['failIfUnavailable']
    assert policy['sandbox']['allowUnsandboxedCommands'] is False
    assert str(seat) in policy['sandbox']['filesystem']['allowRead']
    (output / 'launches.json').write_text(json.dumps(rows, indent=2))
    (output / 'claude-settings.json').write_text(json.dumps(policy, indent=2))
    print('PASS four seat policies, scratch, explicit/custom Astra model, mismatch-form refusal', flush=True)
    prefix = ['env', 'TMPDIR=' + str(seat / 'scratch'), 'codex', 'sandbox', '-C', str(seat), '-P', 'panel-seat', '-c', 'permissions.panel-seat.filesystem={":root"="deny",":minimal"="read",":slash_tmp"="deny",":workspace_roots"="write"}']
    commands = [
        ('read-seat', ['cat', str(seat / 'intake.txt')], 0),
        ('scratch', ['/bin/sh', '-c', 'printf test > "$1/scratch/x"', 'probe', str(seat)], 0),
        ('read-repo', ['cat', str(repo / 'fish/internal/tmux/tai.fish')], 1),
        ('ls-repo', ['ls', str(repo)], 1),
        ('cd-repo-metadata-only', ['/bin/sh', '-c', 'cd "$1"', 'probe', str(repo)], 0),
        ('cd-repo-read', ['/bin/sh', '-c', 'cd "$1" && cat fish/internal/tmux/tai.fish', 'probe', str(repo)], 1),
        ('read-peer', ['cat', str(peer / 'private.txt')], 1),
        ('write-outside', ['/bin/sh', '-c', 'printf test > "$1/x"', 'probe', str(peer)], 1),
        ('chain-outside', ['/bin/sh', '-c', 'cat intake.txt; cat "$1/private.txt"', 'probe', str(peer)], 1),
    ]
    results = []
    for name, command, expected in commands:
        result = subprocess.run(prefix + command, capture_output=True, text=True, timeout=15)
        results.append(dict(name=name, exit=result.returncode, stdout=result.stdout, stderr=result.stderr))
        (output / 'native-codex.json').write_text(json.dumps(results, indent=2))
        assert result.returncode == expected, results[-1]
    assert not (peer / 'x').exists()
    (output / 'native-codex.json').write_text(json.dumps(results, indent=2))
    print('PASS native Codex seat read/scratch; repo, peer, outside writes and chained escape blocked', flush=True)
    scratch = seat / 'scratch'
    subprocess.run(['trash', str(scratch)], check=True)
    scratch.symlink_to(peer)
    result = subprocess.run([str(repo / 'tmux/tools/panel-seat-trust'), 'claude', str(seat)], env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 1 and 'real directory inside the seat' in result.stderr
    print('PASS scratch symlink cannot redirect outside the seat', flush=True)
    (output / 'PASS').write_text('launch and native Codex confinement checks passed\n')
finally:
    alias = Path('/private/tmp') / ('panel-' + str(seat.stat().st_ino))
    if alias.is_symlink():
        subprocess.run(['trash', str(alias)], check=True)
    subprocess.run(['trash', str(seat), str(peer)], check=True)
