#!/usr/bin/python3
"""Drive the exact native controller against signed private clients; never Codex."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--pin', required=True)
args = parser.parse_args()
base = Path(__file__).resolve().parent
helper = base.parent / 'cleanup_guard.py'
if not os.environ.get('KS01_RUN_CAP'):
    raise RuntimeError('run this driver through cleanup_guard supervise')
lease = Path(subprocess.run(['/usr/bin/python3', str(helper), 'records'], capture_output=True, check=True).stdout.decode().strip())
root = lease / ('k71-controller-' + uuid.uuid4().hex[:8])
controller = base / 'window-native-e2e.py'
runtime = Path.home() / 'desk/tmp/angelstar-worktree-target/debug/angelstar-runtime'
child = subprocess.Popen(['/usr/bin/python3', '-B', str(controller), '--pin', args.pin,
                          '--mode', 'codex-keepers', '--private-fixture', str(runtime), str(root)],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
buffer = b''
events = []

def receive(wanted, seconds=90):
    global buffer
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if b'\n' in buffer:
            line, buffer = buffer.split(b'\n', 1)
            if not line.startswith(b'{'):
                continue
            event = json.loads(line)
            events.append(event)
            if event.get('event') in ('hold', 'admission-exception'):
                raise RuntimeError('controller failed: ' + json.dumps(event))
            if wanted(event):
                return event
        else:
            ready, _, _ = select.select([child.stdout], [], [], min(1, max(0, deadline-time.monotonic())))
            if ready:
                chunk = os.read(child.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError('controller output ended; stderr=' + child.stderr.read().decode())
                buffer += chunk
    raise RuntimeError('private driver event deadline expired')

def send(command):
    child.stdin.write((command + '\n').encode())
    child.stdin.flush()

def readiness():
    for _ in range(40):
        send('inspect')
        if receive(lambda e: e.get('event') == 'startup-check')['safe']:
            return
    raise RuntimeError('private fixture never became Rust-ready')

error = None
try:
    receive(lambda e: e.get('event') == 'window-created')
    for case in ('draft', 'positive'):
        send('launch codex ' + case)
        launched = receive(lambda e: e.get('event') == 'client-launched')
        readiness()
        send('seed')
        receive(lambda e: e.get('event') == 'synthetic-draft-seeded')
        readiness()
        send('deliver')
        receive(lambda e: e.get('event') == 'sender-launched')
        for _ in range(60):
            send('observe')
            event = receive(lambda e: e.get('event') in ('draft-oracle', 'positive-oracle', 'sender-pending', 'native-user-turn-pending'))
            if event.get('keeper_proven') is True:
                break
        else:
            raise RuntimeError('private sender/oracle never completed')
        send('done')
        receive(lambda e: e.get('event') == 'pane-removed' and e.get('pane') == launched['pane'])
        # The next launch is sent only after the target removal. Positive's
        # decoy-removal event may precede it, but commands remain sequential.
    send('finish')
    receive(lambda e: e.get('event') == 'signed-private-server-retired')
    deadline = time.monotonic() + 5
    while child.poll() is None and time.monotonic() < deadline:
        select.select([], [], [], .01)
    if child.poll() != 0:
        raise RuntimeError('private controller did not exit zero')
    result_path = root / 'result.json'
    data = result_path.read_bytes()
    result = json.loads(data)
    if (result['error'] is not None or not result['cleanup_proven'] or not result['private_server_retired']
            or result['completed'] != [['codex', 'draft'], ['codex', 'positive']]):
        raise RuntimeError('private controller result incomplete')
    evidence = dict(source_pin=args.pin, result_path=str(result_path), result_sha256=hashlib.sha256(data).hexdigest(),
                    controller_sha256=hashlib.sha256(controller.read_bytes()).hexdigest(),
                    fixture_only=True, real_codex_launched=False, result=result)
    destination = Path.home() / 'desk/audits/relay/rustify/review/k71-private-dryrun.json'
    destination.write_text(json.dumps(evidence, indent=2) + '\n')
    print(json.dumps(dict(private_dry_run='PASS', original_result=str(result_path),
                         result_sha256=evidence['result_sha256'], completed=result['completed'])), flush=True)
except Exception as exc:
    error = str(exc)
    print(json.dumps(dict(private_dry_run='HOLD', root=str(root), exception_type=type(exc).__name__,
                          message=error.replace(str(Path.home()), '$HOME'),
                          missing_path=(str(exc.filename).replace(str(Path.home()), '$HOME')
                                        if getattr(exc, 'filename', None) else None))), flush=True)
finally:
    if child.poll() is None:
        try:
            send('finish')
        except (OSError, ValueError):
            pass
        deadline = time.monotonic() + 10
        while child.poll() is None and time.monotonic() < deadline:
            select.select([], [], [], .02)
    if error:
        raise SystemExit(1)
