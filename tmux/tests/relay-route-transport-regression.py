import importlib.util
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('transport', root/'tests/relay-delivery-regression.py')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
output = Path(sys.argv[1]).resolve()
matrix = transport.Matrix(output)
try:
    target_session, target_window, target_directory = matrix.start('cc-msg.sh','cross-target')
    command = matrix.command
    def cross(relay, session, window, payload, extra=None, source=True):
        argv, env = command(relay, target_session, target_window, payload, extra, source=source)
        env.update(CC_MSG_QUEUE_INTERNAL='0', CC_MSG_INBOX_ROOT=str(output/'inbox'))
        env.pop('RELAY_MESSAGE_RECORD', None)
        return argv, env
    matrix.command = cross
    for agent in ['codex','agy','gemini','claude']:
        matrix.sender_case('cross-refused-'+agent,agent,code=1)
    assert not list((output/'inbox').glob('*/*.json'))
    def local(relay, session, window, payload, extra=None, source=True):
        argv, env = command(relay,session,window,payload,extra,source=source)
        env.update(CC_MSG_QUEUE_INTERNAL='0',CC_MSG_INBOX_ROOT=str(output/'inbox'))
        env.pop('RELAY_MESSAGE_RECORD',None)
        return argv,env
    matrix.command = local
    for agent in ['codex','agy']:
        matrix.sender_case('local-queued-'+agent,agent)
    records = [json.loads(path.read_text()) for path in (output/'inbox').glob('*/*.json')]
    assert len(records) == 2 and all(row['state'] == 'delivered' and row['source']['session'] == row['session'] for row in records), records
    matrix.command = command
    for relay in ['cc-msg.sh','codex-send-to','codex-send','agy-send-to']:
        session, window, directory = matrix.start('cc-msg.sh','unresolved-'+relay)
        argv, env = command(relay,session,window,'unresolved payload')
        if relay == 'agy-send-to':
            argv.insert(1,window)
            env['AGY_SEND_SESSION'] = session
        env.pop('TMUX_PANE',None)
        env.pop('RELAY_MESSAGE_RECORD',None)
        result = transport.subprocess.run(argv,env=env,capture_output=True,text=True,timeout=20)
        matrix.record(relay,'unresolved-'+relay,result,1,directory,no_input=True)
    assert not (target_directory/'wire.bin').exists()
finally:
    matrix.close()
assert all(row['passed'] for row in matrix.results), matrix.results
print(f'PASS: {len(matrix.results)} private routing transport cases; rejected messages produce no input or inbox mutation')
