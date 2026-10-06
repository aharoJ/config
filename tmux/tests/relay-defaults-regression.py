import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time

source = Path(__file__).with_name('relay-delivery-regression.py')
spec = importlib.util.spec_from_file_location('fixtures', source)
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)
if len(sys.argv) > 1:
    fixtures.ROOT = Path(sys.argv[1]).resolve()
os.environ.pop('CC_MSG_QUEUE_INTERNAL', None)
os.environ.pop('CODEX_SEND_QUEUE_INTERNAL', None)
os.environ.pop('TMUX_PANE', None)
output = Path.home() / ('desk/lab/t3/relay-tests-' + str(os.getpid()))
matrix = fixtures.Matrix(output)
def send(relay, name, payload='hello', mode='idle', operator=False, index=False, queued=False, locked=False):
    session, window, directory = matrix.start(relay, name, mode=mode, width=192)
    kind = 'claude' if relay == 'cc-msg.sh' else 'codex'
    matrix.tmux('rename-window', '-t', '=' + session + ':=' + window, kind)
    pane = matrix.tmux('list-panes', '-t', '=' + session, '-F', '#{pane_id}')
    argv, env = matrix.command(relay, session, kind, payload)
    env.pop('CC_MSG_SESSION', None)
    env.pop('CC_MSG_WINDOW', None)
    env.pop('CODEX_SEND_SESSION', None)
    env.pop('CODEX_SEND_WINDOW', None)
    env['TMUX_PANE'] = pane
    env['CC_MSG_INBOX_ROOT'] = str(output / 'inbox')
    if index:
        idx = matrix.tmux('display-message', '-p', '-t', pane, '#{window_index}')
        env['CC_MSG_WINDOW' if kind == 'claude' else 'CODEX_SEND_WINDOW'] = idx
    if operator:
        argv.insert(1, '--operator' if kind == 'claude' else '-O')
    lock = None
    if locked:
        stat = Path(env['TMUX'].split(',')[0]).stat()
        key = hashlib.sha256(f'{stat.st_dev}:{stat.st_ino}:{pane}'.encode()).hexdigest()
        lock = Path(env['TMUX_RELAY_LOCK_ROOT']) / key
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text(str(os.getpid()))
    result = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=45)
    if queued or locked:
        assert result.returncode == 6, result
        assert not (directory / 'wire.bin').exists(), result
        if lock:
            lock.unlink()
        else:
            matrix.tmux('send-keys', '-t', pane, 'C-e', 'C-u')
        for _ in range(150):
            if (directory / 'submitted.json').exists():
                break
            time.sleep(.1)
    else:
        assert result.returncode == 0, (name, result.stdout, result.stderr)
    for _ in range(30):
        if (directory / 'submitted.json').exists():
            break
        time.sleep(.1)
    values = json.loads((directory / 'submitted.json').read_text())
    assert len(values) == 1, (name, values)
    if len(payload) > 200:
        assert values[0].startswith('Read '), values
        path = Path(values[0][5:]).expanduser()
        assert path.read_text() == payload, (path, path.read_text())
        assert path.stat().st_mode & 0o077 == 0
    else:
        expected = ('relay: ' if kind == 'claude' else '') + payload
        assert values == [expected], (name, values, expected)
    print('PASS', relay, name, flush=True)
    matrix.cleanup_session(session)
try:
    for relay in ['cc-msg.sh', 'codex-send']:
        send(relay, 'defaults')
        send(relay, 'index', index=True)
        send(relay, 'long', payload='First line\n' + ('many  words\t' * 100) + '\nFinal line')
        send(relay, 'draft-preserved-then-queued', mode='operator-draft', queued=True)
        send(relay, 'operator-replaces-draft', mode='operator-draft', operator=True)
        send(relay, 'operator-interrupts-busy', mode='operator-busy', operator=True)
        send(relay, 'operator-lock-is-queued', operator=True, locked=True)
        if relay == 'codex-send':
            send(relay, 'operator-slash-command', payload='/help', operator=True)
finally:
    matrix.close()
