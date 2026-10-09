import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('transport', ROOT/'tests/relay-delivery-regression.py')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
output = Path(sys.argv[1]).resolve()
matrix = transport.Matrix(output, validated_sources=True)
command = matrix.command

def public(relay, session, window, text, extra=None, source=True):
    argv,env = command(relay,session,window,text,extra,source)
    env.update(CC_MSG_QUEUE_INTERNAL='0',CODEX_SEND_QUEUE_INTERNAL='0',CC_MSG_INBOX_ROOT=str(output/'inbox'))
    env.pop('RELAY_MESSAGE_RECORD',None)
    return argv,env

matrix.command = public
try:
    for app in ('claude','codex','agy','gemini'):
        matrix.sender_case('unattested-source-'+app,app,code=1,attested=False)
    matrix.sender_case('unattested-node-source','codex',code=1,node=True,attested=False)
    for app in ('claude','codex','agy','gemini'):
        session,window,directory = matrix.start('cc-msg.sh','unattested-target-'+app)
        actor = matrix.target_actor(app)
        rows = json.loads(matrix.attestations.read_text())
        matrix.attestations.write_text(json.dumps([row for row in rows if row['executable'][0] != str(actor)]))
        pane = matrix.tmux('display-message','-p','-t','='+session+':='+window,'#{pane_id}')
        renderer = [sys.executable,str(ROOT/'tests/relay-delivery-regression.py'),'--fixture',str(directory),'❯','idle']
        matrix.tmux('respawn-pane','-k','-t',pane,shlex.join(['exec',str(actor),*renderer]))
        until = time.monotonic()+3
        while matrix.tmux('display-message','-p','-t',pane,'#{pane_current_command}') != app:
            assert time.monotonic()<until
            time.sleep(.02)
        argv,env = public('cc-msg.sh',session,window,'must not reach a basename impostor')
        result = subprocess.run(argv,env=env,capture_output=True,text=True,timeout=45)
        matrix.record('cc-msg.sh','unattested-target-'+app,result,1,directory,no_input=True)
        matrix.cleanup_session(session)
    assert not list((output/'inbox').glob('*/*.json')), 'impostor created an inbox record'
finally:
    matrix.close()
assert all(row['passed'] for row in matrix.results), matrix.results
print('PASS 9 fake vendor executable/Node entrypoint source and target refusals; zero terminal input and inbox records')
