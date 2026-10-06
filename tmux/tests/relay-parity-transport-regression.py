#!/usr/bin/env python3
# path: ~/.config/tmux/tests/relay-parity-transport-regression.py
# description: Exercise real source binding and queued labels on a private fixture server.
# patched: cover coupled and standalone leads without vendor authority
# date: 2026-10-06
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('transport', ROOT / 'tests/relay-delivery-regression.py')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
output = Path(sys.argv[1]).resolve()
matrix = transport.Matrix(output)
tools = output / 'tools'
shutil.copytree(ROOT / 'tools', tools)
original = matrix.command
payload = '(CC) <-> rp / \'single\' "double" $(false) `false` \\ literal'
try:
    def command(relay, session, window, payload, extra=None):
        argv, env = original(relay, session, window, payload, extra)
        argv[0] = str(tools / Path(argv[0]).name)
        env.update(CC_MSG_QUEUE_INTERNAL='0', CC_MSG_INBOX_ROOT=str(output / 'inbox'))
        env.pop('RELAY_MESSAGE_RECORD', None)
        return argv, env
    matrix.command = command
    for provider in ('codex', 'claude', 'agy', 'gemini'):
        matrix.sender_case('queued-source-' + provider, provider, payload=payload)
    matrix.sender_case('queued-node-codex', 'codex', payload=payload, node=True)
    target_session, target_window, target_directory = matrix.start('cc-msg.sh', 'cross-target')
    original_record = matrix.record
    def cross_record(relay, name, result, expected_code, directory, expected_payload=None, no_input=False):
        return original_record(relay, name, result, expected_code, target_directory, expected_payload, no_input)
    matrix.record = cross_record
    for provider in ('codex', 'claude'):
        def cross(relay, session, window, payload, extra=None):
            policy = {'version': 2, 'seats': {session: {'lab-sender-' + provider: 'lead'}, target_session: {target_window: 'lead'}}, 'orchestrator_of': {session: [target_session, target_window]}}
            (tools / 'relay-route-policy.json').write_text(json.dumps(policy))
            argv, env = command(relay, target_session, target_window, payload, extra)
            return argv, env
        matrix.command = cross
        matrix.sender_case('cross-lead-' + provider, provider, payload=payload)
        target_session, target_window, target_directory = matrix.start('cc-msg.sh', 'next-cross-target-' + provider)
    records = [json.loads(path.read_text()) for path in (output / 'inbox').glob('*/*.json')]
    assert len(records) == 7 and all(row['state'] == 'delivered' for row in records), records
finally:
    matrix.close()
assert all(row['passed'] for row in matrix.results), matrix.results
print('PASS: 7 private bound-source queue/label/lead transport cases; no routing stubs')
