import datetime
import json
import runpy
import subprocess
import tempfile
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
guard = runpy.run_path(str(repo / 'tmux/tools/relay-route-guard'))
state = guard['codex_mode'].__globals__
wrapper = repo / 'fish/internal/codex/codex.fish'
script = f"source {wrapper}; function _agent_limit; printf '%s\\n' $argv; end; codex $argv"

positive = [
    ['--image', 'one.png', 'two.png'],
    ['-i', 'one.png', 'two.png', 'three.png'],
    ['--image=one.png'],
    ['--image=one.png', '--', 'prompt'],
    ['-ione.png'],
    ['-ione.png', '--', 'prompt'],
    ['--image', 'exec', 'future-command'],
    ['--image', 'one.png', '--image', 'two.png'],
    ['--image', 'one.png', 'two.png', '--', 'prompt'],
    ['--image', 'one.png', 'two.png', '--model', 'fixture'],
    ['--model-gpt-5-5', '--image', 'one.png', 'two.png'],
    ['--no-daemon', '--image', 'one.png', 'two.png', '--no-daemon'],
    ['resume', 'thread', '--image', 'one.png', 'two.png'],
    ['fork', 'thread', '-i', 'one.png', 'two.png'],
]
negative = [
    ['-ione.png', 'two.png'],
    ['-ione.png', 'future-command'],
    ['-ione.png', 'exec'],
    ['--image=one.png', 'two.png'],
    ['--image=one.png', 'future-command'],
    ['--image=one.png', 'exec'],
    ['future-command'],
    ['--image', 'one.png', 'two.png', '--model', 'fixture', 'future-command'],
    ['--image', 'one.png', 'two.png', '--config', 'model=fixture', 'exec'],
    ['--image', 'one.png', '--remote', 'unix:///remote'],
    ['--image', 'one.png', '--remote-auth-token-env=TOKEN'],
    ['--image', 'one.png', '--future-mode'],
    ['--image', '--no-alt-screen'],
    ['--image=', '--no-alt-screen'],
    ['exec', '--image', 'one.png', 'two.png'],
    ['app-server', '--image', 'one.png', 'two.png'],
    ['--image', 'one.png', '--no-daemon', '--model', 'fixture', 'future-command'],
]
for expected, vectors in [(True, positive), (False, negative)]:
    for argv in vectors:
        result = subprocess.run(['fish', '--no-config', '-c', script, '--', *argv], capture_output=True, text=True, check=True)
        emitted = result.stdout.splitlines()
        state['LABEL']['process_argv'] = lambda pid, emitted=emitted: emitted
        assert guard['codex_mode'](100)[1] == expected, (argv, emitted)
        if expected:
            assert emitted.count('--no-daemon') == 1, emitted
        forced = ['codex', '--no-daemon', *[v for v in emitted[1:] if v != '--no-daemon']]
        state['LABEL']['process_argv'] = lambda pid, forced=forced: forced
        assert guard['codex_mode'](100)[1] == expected, (argv, forced)

dates = ['00000000', '00000101', '20261399', '20260001', '20260100', '20260132', '20260229', '20260230', '20260431', '19000229', '20000229', '20000230', '20240229', '20260101', '20261031', '20261101', '20261102', '99991231', '2026101', '2026-10-01', 'bad', '20261031\n20261031']
dates += [f'2026{month:02d}{day:02d}' for month in range(1, 13) for day in (28, 29, 30, 31)]
with tempfile.TemporaryDirectory(prefix='codex-calendar-', dir=Path.home() / 'desk/tmp') as temp:
    directory = Path(temp)
    provider = directory / 'date'
    for value in dates:
        provider.write_text('#!/bin/sh\nprintf "%s\\n" ' + "'" + value + "'" + '\n')
        provider.chmod(0o700)
        valid = False
        if len(value) == 8 and value.isascii() and value.isdecimal():
            try:
                date = datetime.date(int(value[:4]), int(value[4:6]), int(value[6:]))
                valid = True
            except ValueError:
                pass
        allowed = valid and date < datetime.date(2026, 11, 1)
        for alias in ('--model-lead', '--model-audit'):
            code = f'set -gx PATH {directory} $PATH; ' + script
            result = subprocess.run(['fish', '--no-config', '-c', code, '--', alias], capture_output=True, text=True)
            assert result.returncode == (0 if allowed else 2), (value, alias, result)
            assert bool(result.stdout) == allowed, (value, alias, result)
            if not valid:
                assert 'cannot check preset migration deadline' in result.stderr, (value, result)
            elif not allowed:
                assert 'retired on 2026-11-01' in result.stderr, (value, result)
    provider.write_text('#!/bin/sh\necho 20261031\nexit 1\n')
    for alias in ('--model-lead', '--model-audit'):
        result = subprocess.run(['fish', '--no-config', '-c', code, '--', alias], capture_output=True, text=True)
        assert result.returncode == 2 and not result.stdout, result
    for preset in ('--model-gpt-5-5', '--model-gpt-5-3-codex'):
        result = subprocess.run(['fish', '--no-config', '-c', code, '--', preset], capture_output=True, text=True)
        assert result.returncode == 0 and result.stdout, result

print(json.dumps(dict(image_vectors=len(positive)+len(negative), calendar_alias_checks=2*len(dates), failed_provider_checks=2, explicit_preset_checks=2, passed=True)))
