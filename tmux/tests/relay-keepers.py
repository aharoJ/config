#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import select
import shlex
import subprocess
import sys
import time
import tty

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / 'tools'


def wait(predicate, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(.1)
    raise AssertionError('timed out')


def fixture(folder, kind):
    tty.setraw(sys.stdin.fileno())
    folder = Path(folder)
    value = ''
    pending = b''
    submitted = []
    state = ''
    marker = {'claude': '❯', 'codex': '›', 'agy': '>'}[kind]
    def draw():
        rows = [''] * 15
        if kind == 'claude':
            rows[4] = rows[6] = '─' * 215
            rows[5] = marker + '\xa0' + value
            rows[7] = '  Opus 5.5 | effort medium'
        elif kind == 'agy':
            rows[4] = rows[6] = '─' * 215
            rows[5] = '\x1b[94m>\x1b[39m' + (' ' + value if value else '')
            rows[7] = '? for shortcuts'
        else:
            rows[5] = '\x1b[1m›\x1b[0m ' + (value if value else '\x1b[2mAsk Codex to do anything\x1b[0m')
            rows[7] = '  \x1b[38;2;200;169;238mFast off\x1b[39m · GPT-6.1-Sol low · ~/desk/lab · Context 0% used'
        if state == 'busy':
            rows[3] = '• Working (1s • esc to interrupt)'
        x = 2 + len(value)
        sys.stdout.write('\x1b[?2004h\x1b[2J\x1b[H' + ''.join(f'\x1b[{i+1};1H' + row for i, row in enumerate(rows)) + f'\x1b[6;{x+1}H')
        sys.stdout.flush()
        (folder / 'ready').touch()
    draw()
    while True:
        control = folder / 'control'
        if control.exists():
            command = control.read_text()
            control.rename(folder / ('control-used-' + str(time.time_ns())))
            state = command
            value = 'Angel draft' if command == 'draft' else ''
            draw()
        if not select.select([sys.stdin], [], [], .05)[0]:
            continue
        pending += os.read(sys.stdin.fileno(), 65536)
        (folder / 'wire').write_bytes(pending)
        while pending:
            if pending.startswith(b'\x1b[200~'):
                end = pending.find(b'\x1b[201~', 6)
                if end < 0:
                    break
                value += pending[6:end].decode()
                pending = pending[end + 6:]
                draw()
            elif pending[:1] in (b'\r', b'\n'):
                submitted.append(value)
                (folder / 'submitted.json').write_text(json.dumps(submitted))
                value = ''
                pending = pending[1:]
                draw()
            elif pending[:1] in (b'\x05', b'\x15'):
                if pending[:1] == b'\x15':
                    value = ''
                    draw()
                pending = pending[1:]
            elif b'\x1b[200~'.startswith(pending):
                break
            else:
                raise AssertionError(repr(pending))


def corpus():
    count = 0
    for name in ('relay-must-accept.json', 'relay-must-refuse.json', 'relay-codex-home-drafts.json', 'relay-codex-live-160.json'):
        for case in json.loads((ROOT / 'tests/fixtures' / name).read_text())['cases']:
            capture = case.get('capture')
            if capture is None:
                content = (ROOT / 'tests/fixtures' / case['capture_file']).read_bytes()
                assert hashlib.sha256(content).hexdigest() == case['capture_sha256']
                capture = content.decode()
            result = subprocess.run([str(TOOLS / 'relay-input-guard'), case.get('glyph', '›'), str(case['cursor_x']), str(case['cursor_y']), str(case.get('pane_width', 167))], input=capture, capture_output=True, text=True, timeout=5)
            assert result.returncode == case['input_exit'], (name, case['name'], result.returncode)
            count += 1
    print('PASS', count, 'captured empty/draft composer cases', flush=True)


def lab(output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, CC_MSG_INBOX_ROOT=str(output / 'inbox'))
    def tmux(*args):
        return subprocess.check_output([env['TMUX_BIN'], '-L', env['TMUX_LAB_SOCKET'], '-f', '/dev/null', *args], env=env, text=True, timeout=5).strip()
    session = 'config::relay-lab'
    folders = {}
    for kind in ('claude', 'codex', 'agy'):
        folder = output / kind
        folder.mkdir()
        folders[kind] = folder
        command = shlex.join(['exec', sys.executable, str(Path(__file__).resolve()), '--fixture', str(folder), kind])
        if kind == 'claude':
            tmux('new-session', '-d', '-s', 'lab-relay', '-n', kind, '-x', '215', '-y', '15', command)
            sid = next(row.split('\t')[0] for row in tmux('list-sessions', '-F', '#{session_id}\t#{session_name}').splitlines() if row.split('\t')[1] == 'lab-relay')
            tmux('rename-session', '-t', sid, session)
        else:
            tmux('new-window', '-d', '-t', sid, '-n', kind, command)
        tmux('set-option', '-t', sid, 'automatic-rename', 'off')
        wait(lambda: (folder / 'ready').exists())
    pane_ids = {row.split('\t')[0]: row.split('\t')[1] for row in tmux('list-panes', '-s', '-t', sid, '-F', '#{window_name}\t#{pane_id}').splitlines()}
    def send(source, destination, message):
        adapter = 'cc-msg.sh' if destination == 'claude' else 'codex-send-to' if destination == 'codex' else 'agy-send-to'
        command = [str(TOOLS / adapter)] + ([] if destination == 'claude' else [destination]) + [message]
        result = subprocess.run(command, env=dict(env, TMUX_PANE=pane_ids[source], CC_MSG_SESSION=session, CC_MSG_WINDOW=destination, CODEX_SEND_SESSION=session, AGY_SEND_SESSION=session), capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, (result.stdout, result.stderr)
        with (output / 'sends.jsonl').open('a') as stream:
            stream.write(json.dumps(dict(source=source, destination=destination, message=message, stdout=result.stdout)) + '\n')
    def submissions(kind):
        path = folders[kind] / 'submitted.json'
        return json.loads(path.read_text()) if path.exists() else []
    send('codex', 'claude', '#lab1 ping')
    wait(lambda: submissions('claude'))
    assert submissions('claude') == ['codex (' + session + ':codex): #lab1 ping']
    send('claude', 'codex', '#lab1 pong')
    wait(lambda: submissions('codex'))
    assert submissions('codex') == ['claude (' + session + ':claude): #lab1 pong']
    print('PASS colon-session CC/Codex exchange and sender/code', flush=True)
    (folders['claude'] / 'control').write_text('draft')
    time.sleep(.2)
    send('codex', 'claude', '#lab2 waiting')
    time.sleep(.5)
    assert len(submissions('claude')) == 1
    assert 'Angel draft' in tmux('capture-pane', '-p', '-t', pane_ids['claude'])
    (folders['claude'] / 'control').write_text('clear')
    wait(lambda: len(submissions('claude')) == 2)
    print('PASS draft preserved; automatic retry submits once after clear', flush=True)
    (folders['codex'] / 'control').write_text('busy')
    time.sleep(.2)
    send('claude', 'codex', '#lab3 during reply')
    wait(lambda: len(submissions('codex')) == 2)
    print('PASS empty busy composer accepts peer message', flush=True)
    send('codex', 'agy', '#lab4 ping')
    wait(lambda: submissions('agy'))
    print('PASS agy adapter preserves sender/code', flush=True)
    (folders['claude'] / 'control').write_text('draft')
    time.sleep(.2)
    result = subprocess.run([str(TOOLS / 'cc-msg.sh'), '--clear-draft', '--expect', 'Angel draft'], env=dict(env, CC_MSG_SESSION=session, CC_MSG_WINDOW='claude'), capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert 'Angel draft' not in tmux('capture-pane', '-p', '-t', pane_ids['claude'])
    assert len(submissions('claude')) == 2
    print('PASS explicit clear uses the helper on the named pane', flush=True)
    replacement = output / 'respawn-codex'
    replacement.mkdir()
    command = shlex.join(['fish', '-C', shlex.join([sys.executable, str(Path(__file__).resolve()), '--fixture', str(replacement), 'codex'])])
    tmux('respawn-pane', '-k', '-t', pane_ids['codex'], command)
    folders['codex'] = replacement
    wait(lambda: (replacement / 'ready').exists())
    send('claude', 'codex', '#lab6 respawn fish seat')
    wait(lambda: submissions('codex'))
    assert '#lab6' in submissions('codex')[0]
    print('PASS respawn-pane + fish -C seat receives the peer message', flush=True)
    result = subprocess.run([str(TOOLS / 'relay'), session + ':missing', '#lab5 wrong target'], env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 1
    assert len(submissions('claude')) == 2 and len(submissions('codex')) == 1
    print('PASS missing exact target sends no input to another pane', flush=True)
    records = set((output / 'inbox').glob('*/*.json'))
    for option in ('--check-binding', '--watch-worker'):
        result = subprocess.run([str(TOOLS / 'cc-msg-queue'), option, '{}'], env=dict(env, CC_MSG_SESSION=session, CC_MSG_WINDOW='claude'), capture_output=True, text=True, timeout=10)
        assert result.returncode == 1 and 'no target input was sent' in result.stderr
    for option in ('--schedule', '--worker', '--sweep'):
        result = subprocess.run([str(TOOLS / 'cc-msg-queue'), option, '/unused', '7'], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0
    assert set((output / 'inbox').glob('*/*.json')) == records
    assert len(submissions('claude')) == 2 and len(submissions('codex')) == 1
    print('PASS retired internal calls create no messages or pane input', flush=True)
    cc_env = dict(env, TMUX_PANE=pane_ids['claude'], CC_MSG_SESSION=session, CC_MSG_WINDOW='claude')
    for args, reason in ((['#self accidental'], 'self-send refused'), (['portfolio:claude', '#self misplaced'], 'session:window positional'), (['config::other:claude', '#self colon target'], 'session:window positional')):
        result = subprocess.run([str(TOOLS / 'cc-msg.sh'), *args], env=cc_env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 1 and reason in result.stderr, (result.stdout, result.stderr)
    assert set((output / 'inbox').glob('*/*.json')) == records and len(submissions('claude')) == 2
    result = subprocess.run([str(TOOLS / 'cc-msg.sh'), '--allow-self', '#self explicit'], env=cc_env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, (result.stdout, result.stderr)
    wait(lambda: len(submissions('claude')) == 3)
    assert submissions('claude')[-1] == 'claude (' + session + ':claude): #self explicit'
    print('PASS cc-msg rejects self-send/address misuse; explicit self-send works', flush=True)
    (output / 'PASS').write_text('keeper corpus and private tmux transport passed\n')


if __name__ == '__main__':
    if sys.argv[1:2] == ['--fixture']:
        fixture(*sys.argv[2:])
    else:
        corpus()
        lab(sys.argv[1])
