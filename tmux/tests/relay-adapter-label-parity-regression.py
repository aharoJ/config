#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('state', ROOT / 'tests/relay-state-regression.py')
state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(state)
state.delivery.__file__ = str(ROOT / 'tests/relay-delivery-regression.py')
output = Path(sys.argv[1]).resolve()
matrix = state.StateMatrix(output)
tools = output / 'tools'
shutil.copytree(ROOT / 'tools', tools)
base_command = matrix.command
base_record = matrix.record
try:
    for provider, adapter in [('claude', 'codex-send-to'), ('codex', 'agy-send-to'), ('agy', 'cc-msg.sh')]:
        for archived in (False, True):
            target_session, target_window, target_directory = matrix.start(adapter, provider + ('-archive' if archived else '-direct'), width=260)
            payload = ("literal sender's quote " + ('long archive payload ' * 90 if archived else 'direct')).rstrip()
            def command(relay, session, window, message, extra=None):
                policy = dict(version=2, seats={session:{'lab-sender-' + provider:'lead'}, target_session:{target_window:'lead'}}, orchestrator_of={session:[target_session,target_window]})
                (tools / 'relay-route-policy.json').write_text(json.dumps(policy))
                argv, env = base_command(adapter, target_session, target_window, message, extra)
                argv[0] = str(tools / adapter)
                env.update(CC_MSG_QUEUE_INTERNAL='0', CODEX_SEND_QUEUE_INTERNAL='0', AGY_SEND_QUEUE_INTERNAL='0', CC_MSG_INBOX_ROOT=str(output / 'inbox'))
                env.pop('RELAY_MESSAGE_RECORD', None)
                return argv, env
            def record(relay, name, result, expected_code, directory, expected_payload=None, no_input=False):
                return base_record(relay, name, result, expected_code, target_directory, expected_payload, no_input)
            matrix.command = command
            matrix.record = record
            matrix.sender_case(provider + '-to-' + adapter + ('-archive' if archived else '-direct'), provider, payload=payload)
    records = [json.loads(path.read_text()) for path in (output / 'inbox').glob('*/*.json')]
    assert len(records) == 6 and all(row['state'] == 'delivered' for row in records), records
except BaseException:
    for session in matrix.sessions.copy():
        for pane in matrix.tmux('list-panes', '-t', '=' + session, '-F', '#{pane_id}').splitlines():
            (output / ('failure-' + session + '-' + pane[1:] + '.txt')).write_text(matrix.tmux('capture-pane', '-p', '-t', pane))
    raise
finally:
    matrix.close()
assert all(row['passed'] for row in matrix.results), matrix.results
print('PASS: six native source/target adapter transports preserve uniform direct and archive labels across Claude, Codex and Agy; real routing guards')
