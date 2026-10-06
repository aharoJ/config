#!/usr/bin/env python3
import codecs
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

def fixture(folder, kind):
    tty.setraw(sys.stdin.fileno())
    folder = Path(folder)
    if kind == 'claude':
        empty = (ROOT / 'tests/fixtures/cc-title-empty.ansi').read_text().splitlines()
        y = 46
        glyph = '❯'
        base = empty
    else:
        case = next(row for row in json.loads((ROOT / 'tests/fixtures/relay-codex-live-160.json').read_text())['cases'] if row['name'] == 'sol-truecolor-fresh')
        empty = case['capture'].splitlines()
        y = case['cursor_y']
        glyph = '›'
        base = (ROOT / 'tests/fixtures/codex-new-live-real-busy-draft.ansi').read_text().splitlines()
    value = ''
    pending = b''
    submissions = []
    decoder = codecs.getincrementaldecoder('utf-8')()
    released = kind == 'claude'
    def draw():
        rows = list(base)
        cursor_y = y if released else max(i for i, row in enumerate(rows) if glyph in row and row.lstrip('\x1b[0123456789;m').startswith(glyph))
        x = 2
        if released and value:
            rows[y] = '\x1b[39m' + glyph + '\xa0' + value
            x += len(value)
        elif not released:
            import re
            visible = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', rows[cursor_y])
            x = len(visible)
        text = '\x1b[?2004h\x1b[2J\x1b[H'
        for index, row in enumerate(rows):
            text += f'\x1b[{index+1};1H' + row
        text += f'\x1b[{cursor_y+1};{x+1}H'
        sys.stdout.write(text)
        sys.stdout.flush()
        (folder / 'ready').touch()
    draw()
    while True:
        if not released and (folder / 'release').exists():
            released = True
            base = empty
            draw()
        if not select.select([sys.stdin], [], [], .1)[0]:
            continue
        wire = os.read(sys.stdin.fileno(), 65536)
        if not wire:
            return
        with (folder / 'wire.bin').open('ab') as stream:
            stream.write(wire)
        pending += wire
        while pending:
            if pending.startswith(b'\x1b[200~'):
                end = pending.find(b'\x1b[201~', 6)
                if end < 0:
                    break
                value += decoder.decode(pending[6:end])
                pending = pending[end+6:]
                draw()
            elif pending[:1] in (b'\r', b'\n'):
                submissions.append(value)
                (folder / 'submitted.json').write_text(json.dumps(submissions))
                value = ''
                pending = pending[1:]
                draw()
            elif b'\x1b[200~'.startswith(pending):
                break
            else:
                raise RuntimeError('unexpected test input')

def run(output):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    socket = f'ccmsg-lab-private-{os.getpid()}'
    wrapper = output / 'tmux-private'
    wrapper.write_text('#!/bin/sh\nexec tmux -L '+socket+' -f /dev/null "$@"\n')
    wrapper.chmod(0o700)
    def tmux(*args):
        return subprocess.check_output([str(wrapper), *args], text=True, timeout=5).strip()
    try:
        for kind in ['claude', 'codex']:
            folder = output / kind
            folder.mkdir()
            session = 'lab-real-relay-' + kind
            command = shlex.join(['exec', sys.executable, str(Path(__file__).resolve()), '--fixture', str(folder), kind])
            tmux('new-session', '-d', '-s', session, '-n', kind, '-x', '215' if kind == 'codex' else '167', '-y', '51', command)
            tmux('set-option', '-w', '-t', '='+session+':='+kind, 'automatic-rename', 'off')
            for _ in range(100):
                if (folder / 'ready').exists():
                    break
                time.sleep(.05)
            assert (folder / 'ready').exists(), kind
            context = tmux('display-message', '-p', '-t', '='+session+':='+kind, '#{socket_path},#{pid},0')
            env = dict(os.environ, TMUX=context, TMUX_BIN=str(wrapper), CC_MSG_SESSION=session, CC_MSG_WINDOW=kind, CODEX_SEND_SESSION=session, CC_MSG_INBOX_ROOT=str(output/'inbox'), TMPDIR=str(output), TMUX_RELAY_LOCK_ROOT=str(output/'locks'))
            for key in ['CC_MSG_QUEUE_INTERNAL','CODEX_SEND_QUEUE_INTERNAL','TMUX_PANE','RELAY_QUEUE_AGENT']:
                env.pop(key,None)
            if kind == 'claude':
                command = [str(ROOT/'tools/cc-msg.sh'), 'Real titled composer receipt']
            else:
                command = [str(ROOT/'tools/codex-send-to'), 'codex', 'Standing instruction after work']
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=60)
            (folder/'relay.json').write_text(json.dumps(dict(exit=result.returncode,stdout=result.stdout,stderr=result.stderr),indent=2)+'\n')
            if kind == 'codex':
                assert result.returncode == 6, (result.returncode,result.stdout,result.stderr)
                assert not (folder/'wire.bin').exists()
                (folder/'release').touch()
            else:
                assert result.returncode == 0, (result.returncode,result.stdout,result.stderr)
            for _ in range(300):
                records=list((output/'inbox').glob(session+'-*/*.json'))
                if records and json.loads(records[0].read_text())['state'] == 'delivered':
                    break
                time.sleep(.1)
            assert records and json.loads(records[0].read_text())['state'] == 'delivered'
            expected = 'unverified (unverified:unverified) [model/effort unverified]: ' + ('Real titled composer receipt' if kind == 'claude' else 'Standing instruction after work')
            assert json.loads((folder/'submitted.json').read_text()) == [expected]
            (folder/'capture-after.ansi').write_text(tmux('capture-pane','-p','-e','-t','='+session+':='+kind)+'\n')
            print('PASS',kind,'real-capture replay; one confirmed submission',flush=True)
    finally:
        subprocess.run([str(wrapper),'kill-server'],capture_output=True,timeout=5)

if __name__ == '__main__':
    if sys.argv[1:2] == ['--fixture']:
        fixture(*sys.argv[2:])
    else:
        if len(sys.argv) > 2:
            ROOT = Path(sys.argv[2]).resolve()
        run(sys.argv[1])
