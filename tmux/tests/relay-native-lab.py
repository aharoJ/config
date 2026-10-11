#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, CC_MSG_INBOX_ROOT=str(output / 'inbox'))
session = 'config::native-relay'


def tmux(*args):
    return subprocess.check_output([env['TMUX_BIN'], '-L', env['TMUX_LAB_SOCKET'], '-f', '/dev/null', *args], env=env, text=True, timeout=5).strip()


def wait(predicate, timeout=120):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(.5)
    raise AssertionError('native lab timed out; captures in ' + str(output))


def capture(kind):
    value = tmux('capture-pane', '-p', '-e', '-t', panes[kind])
    (output / (kind + '-capture.ansi')).write_text(value)
    return value


def answered(kind, text):
    value = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', capture(kind))
    return re.search(r'^\s*[•⏺] ' + re.escape(text) + r'\s*$', value, re.MULTILINE) is not None


def send(source, destination, message):
    command = [str(TOOLS / ('cc-msg.sh' if destination == 'claude' else 'codex-send-to'))]
    if destination == 'codex':
        command.append('codex')
    result = subprocess.run(command + [message], env=dict(env, TMUX_PANE=panes[source], CC_MSG_SESSION=session, CC_MSG_WINDOW=destination, CODEX_SEND_SESSION=session), text=True, capture_output=True, timeout=10)
    with (output / 'sends.jsonl').open('a') as stream:
        stream.write(json.dumps(dict(source=source, destination=destination, message=message, exit=result.returncode, out=result.stdout, err=result.stderr)) + '\n')
    assert result.returncode == 0, (result.stdout, result.stderr)
    return next(path for path in (output / 'inbox').glob('*/*.json') if json.loads(path.read_text())['message'] == message)


def delivered(path):
    data = json.loads(path.read_text())
    assert data['state'] != 'error', data
    return data['state'] == 'delivered'


claude = str(Path.home() / '.local/bin/claude')
codex = subprocess.check_output(['which', 'codex'], text=True).strip()
native_env = [key + '=' + value for key, value in env.items() if key.startswith('TMUX_LAB_') or key in ('TMUX_BIN', 'CC_MSG_INBOX_ROOT')]
tmux('new-session', '-d', '-s', 'lab-native-relay', '-n', 'claude', '-c', str(output), '-x', '215', '-y', '50', shlex.join(['exec', 'env', *native_env, claude, '--dangerously-skip-permissions']))
sid = next(row.split('\t')[0] for row in tmux('list-sessions', '-F', '#{session_id}\t#{session_name}').splitlines() if row.split('\t')[1] == 'lab-native-relay')
tmux('rename-session', '-t', sid, session)
tmux('set-option', '-t', sid, 'automatic-rename', 'off')
tmux('new-window', '-d', '-t', sid, '-n', 'codex', '-c', str(output), shlex.join(['exec', 'env', *native_env, codex, '--no-daemon', '--no-alt-screen', '--dangerously-bypass-approvals-and-sandbox']))
panes = {row.split('\t')[0]: row.split('\t')[1] for row in tmux('list-panes', '-s', '-t', sid, '-F', '#{window_name}\t#{pane_id}').splitlines()}
(output / 'seats.json').write_text(json.dumps(dict(session=session, sid=sid, panes=panes, claude=claude, codex=codex, socket=env['TMUX_LAB_SOCKET']), indent=2))
wait(lambda: '❯' in capture('claude'))
if 'Yes, I trust this folder' in capture('claude'):
    result = subprocess.run([str(TOOLS / 'cc-msg.sh'), '--keys', 'Down', 'Enter'], env=dict(env, CC_MSG_SESSION=session, CC_MSG_WINDOW='claude'), text=True, capture_output=True, timeout=10)
    assert result.returncode == 0, (result.stdout, result.stderr)
    wait(lambda: 'Yes, I trust this folder' not in capture('claude') and '❯' in capture('claude'))
wait(lambda: 'Ask Codex to do anything' in capture('codex'))
print('READY actual interactive CC and Codex on private tmux-lab server', flush=True)
reply = shlex.join(['env', 'CODEX_SEND_SESSION=' + session, str(TOOLS / 'codex-send-to'), 'codex', '#native1 pong; reply only NATIVE_PONG_OK.'])
cc_message = '#native1 Private relay lab. Run this exact shell command to reply to the Codex peer: ' + reply + ' Then reply only NATIVE_CC_DONE. No other work.'
request = send('codex', 'claude', cc_message)
wait(lambda: delivered(request))
wait(lambda: answered('claude', 'NATIVE_CC_DONE') and answered('codex', 'NATIVE_PONG_OK'))
captures = {kind: capture(kind) for kind in panes}
assert 'claude (' + session + ':claude)' in captures['codex']
assert 'codex (' + session + ':codex)' in captures['claude']
print('PASS actual CC -> Codex reply with #native1 and sender labels', flush=True)
time.sleep(1)
tmux('send-keys', '-t', panes['codex'], '-l', 'OWNED_NATIVE_DRAFT')
wait(lambda: 'OWNED_NATIVE_DRAFT' in capture('codex'))
request = send('claude', 'codex', '#native2 Reply only NATIVE_DRAFT_RELEASE_OK.')
time.sleep(1)
assert json.loads(request.read_text())['state'] in ('pending', 'waiting')
assert 'OWNED_NATIVE_DRAFT' in capture('codex')
tmux('send-keys', '-t', panes['codex'], 'C-u')
wait(lambda: delivered(request))
wait(lambda: answered('codex', 'NATIVE_DRAFT_RELEASE_OK'))
print('PASS actual Codex draft preserved; queued peer message delivered after owned draft cleared', flush=True)
request = send('claude', 'codex', '#native3 Run sleep 8 using exec_command, then reply only NATIVE_BUSY_DONE.')
wait(lambda: delivered(request))
wait(lambda: 'Working' in capture('codex'))
second = send('claude', 'codex', '#native4 Reply only NATIVE_BUSY_PEER_OK.')
wait(lambda: delivered(second))
wait(lambda: answered('codex', 'NATIVE_BUSY_PEER_OK'))
print('PASS actual Codex accepts and answers peer input mid-reply', flush=True)
(output / 'PASS').write_text('actual interactive CC/Codex exchange, draft, busy, colon-session passed\n')
