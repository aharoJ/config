import json
import os
from pathlib import Path
import runpy
import select
import sqlite3
import sys
import termios
import tty

journal, snapshot, control, helper = map(Path, sys.argv[1:5])
extra = sys.argv[5:]
harness = bool(extra)
if harness:
    if len(extra) != 5 or extra[0] != '--codex-harness':
        raise RuntimeError('invalid private harness profile')
    _, session_id, codex_home, cwd, launched_ms = extra
    codex_home = Path(codex_home)
    launched_ms = int(launched_ms)
guard = runpy.run_path(str(helper))
identity = guard['generation'](os.getpid())
fd = os.open(journal, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
before = termios.tcgetattr(0)
draft = bytearray()
events = 0
output_sequence = 0
submissions = 0
submission_sequence = 0
seen_controls = set()
event_fd = os.open(snapshot.with_suffix(".events.jsonl"), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
last = b''
busy = False


def record(origin="state", raw=b""):
    global output_sequence
    output_sequence += 1
    os.write(fd, f'{events}\t{submissions}\t{draft.hex()}\t{last.hex()}\n'.encode())
    body = dict(schema='private-runtime-line-editor-v2', pid=os.getpid(),
                generation=identity, events=events, output_sequence=output_sequence, submission_sequence=submission_sequence, submissions=submissions,
                journal_device=os.fstat(event_fd).st_dev, journal_inode=os.fstat(event_fd).st_ino,
                draft=draft.hex(), last=last.hex(), busy=busy)
    event = dict(schema='private-runtime-event-v1', pid=os.getpid(), generation=identity,
                 sequence=output_sequence, submission_sequence=submission_sequence,
                 submissions=submissions, origin=origin, raw=raw.hex())
    os.write(event_fd, json.dumps(event, separators=(',', ':')).encode() + b'\n')
    temporary = snapshot.with_suffix('.pending')
    out = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        os.write(out, json.dumps(body, separators=(',', ':')).encode())
    finally:
        os.close(out)
    os.replace(temporary, snapshot)


def render():
    if harness:
        # Real terminal output consumed by the unchanged Rust composer probe.
        prompt = '› '.encode() + (bytes(draft) if draft else b'\x1b[2mfixture placeholder\x1b[0m')
        screen = b'\x1b[2J\x1b[H' + prompt + b'\r\n\r\n  fixture \xc2\xb7 ' + session_id.encode()
        screen += ('\x1b[1;%dH' % (len(draft) + 3)).encode()
        os.write(1, screen)
    else:
        os.write(1, b'\r\x1b[2Kfixture> ' + draft)


def persist_turn():
    if not harness:
        return
    # Deliberately absent before first Enter, reproducing the K70 baseline bug.
    with sqlite3.connect(codex_home / 'state_5.sqlite') as db:
        db.execute('INSERT INTO threads VALUES (?,?,?,?,?)',
                   (session_id, cwd, '0.162.1', launched_ms, 'paginated'))
    item = json.dumps(dict(type='userMessage', content=[dict(type='text', text=last.decode())]))
    with sqlite3.connect(codex_home / 'thread_history_1.sqlite') as db:
        db.execute('INSERT INTO thread_items VALUES (?,?,?,?)', (session_id, 'userMessage', submissions, item))



try:
    tty.setraw(0)
    render()
    record()
    while True:
        desired = control.read_text().strip() if control.exists() else 'ready'
        if desired.startswith('{'):
            command = json.loads(desired)
            if set(command) != {'id', 'origin', 'raw'} or command['origin'] not in ('application', 'input-echo'):
                raise RuntimeError('unsupported fixture output command')
            if command['id'] not in seen_controls:
                seen_controls.add(command['id'])
                raw = bytes.fromhex(command['raw'])
                os.write(1, b'\r\n' + raw + b'\r\n')
                render()
                record(command['origin'], raw)
            desired = 'ready'
        if desired not in ('ready', 'busy'):
            raise RuntimeError('unsupported fixture control')
        if busy != (desired == 'busy'):
            busy = desired == 'busy'
            record()
        if not select.select([0], [], [], 0.02)[0]:
            continue
        value = os.read(0, 1)
        if not value:
            break
        events += 1
        if value in (b'\r', b'\n'):
            last = bytes(draft)
            submissions += 1
            submission_sequence = output_sequence + 1
            draft.clear()
            persist_turn()
            os.write(1, b'\r\nsubmitted> ' + last + b'\r\n')
        elif value == b'\x7f':
            if draft:
                draft.pop()
        elif 32 <= value[0] <= 126:
            draft.extend(value)
        else:
            raise RuntimeError('unsupported fixture input byte')
        render()
        record("submission" if value in (b"\r", b"\n") else "input-echo", last if value in (b"\r", b"\n") else value)
finally:
    termios.tcsetattr(0, termios.TCSANOW, before)
    os.close(fd)
    os.close(event_fd)
