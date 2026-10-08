#!/usr/bin/env python3
"""Real private tmux/process/queue/adapter path, inert recognized actors only."""
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
if sys.argv[1:2] == ['--source']:
    folder = Path(sys.argv[2])
    # A renderer and request driver share the inert Claude actor's foreground
    # process group. No real Claude/model executable is started.
    subprocess.Popen([sys.executable,str(ROOT/'tests/relay-delivery-regression.py'),'--fixture',str(folder),'❯','critical-ready'])
    seen = set()
    while True:
        for ready in folder.glob('request-*.ready'):
            if ready in seen:
                continue
            seen.add(ready)
            request = ready.with_suffix('.json')
            data = json.loads(request.read_text())
            result = subprocess.run(data['argv'],env=data['env'],capture_output=True,text=True,timeout=40)
            request.with_suffix('.result').write_text(json.dumps(dict(returncode=result.returncode,stdout=result.stdout,stderr=result.stderr)))
        time.sleep(.02)

spec = importlib.util.spec_from_file_location('transport', ROOT/'tests/relay-delivery-regression.py')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
out = Path(tempfile.mkdtemp(prefix='rn-critical-',dir=Path.home()/'desk/lab'))
tools = out/'tools'
shutil.copytree(ROOT/'tools',tools)
guard = tools/'relay-route-guard'
guard.write_text(guard.read_text().replace("SOURCE_BINDINGS = pathlib.Path(pwd.getpwuid(os.getuid()).pw_dir) / '.local/state/relay/source-bindings.json'",'SOURCE_BINDINGS = pathlib.Path('+repr(str(out/'bindings.json'))+')'))
actor_source = out/'actor.c'
actor_source.write_text('#include <sys/wait.h>\n#include <unistd.h>\nint main(int n,char **v){pid_t p=fork();if(!p){execvp(v[1],v+1);_exit(127);}int s;waitpid(p,&s,0);return 0;}\n')
for app in ('claude','codex','agy'):
    subprocess.run(['cc',str(actor_source),'-o',str(out/app)],check=True,capture_output=True)
matrix = transport.Matrix(out/'matrix')
results = []
providers = ('claude','codex','agy') if len(sys.argv)==1 else (sys.argv[2],)
assert len(sys.argv)==1 or sys.argv[1]=='--provider' and providers[0] in ('claude','codex','agy')
try:
    for app in providers:
        session = 'critical-' + app
        target_dir, sender_dir = out/(app+'-target'),out/(app+'-sender')
        target_dir.mkdir(); sender_dir.mkdir()
        if app == 'agy':
            renderer = [sys.executable,str(ROOT/'tests/relay-ui-regression.py'),'--agy-fixture',str(target_dir)]
        else:
            renderer = [sys.executable,str(ROOT/'tests/relay-delivery-regression.py'),'--fixture',str(target_dir),'❯' if app=='claude' else '›','critical-ready' if app=='claude' else 'codex159-critical-ready']
        matrix.tmux('new-session','-d','-s',session,'-n','lala','-x','400','-y','50',shlex.join(['exec',str(out/app),*renderer]))
        matrix.sessions.add(session)
        target_pane = matrix.tmux('display-message','-p','-t',session+':lala','#{pane_id}')
        matrix.server_address = matrix.tmux('display-message','-p','-t',target_pane,'#{socket_path},#{pid},0')
        matrix.tmux('set-option','-w','-t',target_pane,'automatic-rename','off')
        matrix.tmux('new-window','-d','-t',session,'-n','sender',shlex.join(['exec',str(out/'claude'),sys.executable,str(Path(__file__).resolve()),'--source',str(sender_dir)]))
        sender_pane = matrix.tmux('display-message','-p','-t',session+':sender','#{pane_id}')
        matrix.tmux('set-option','-w','-t',sender_pane,'automatic-rename','off')
        until = time.monotonic()+5
        while not all((folder/'ready').exists() for folder in (target_dir,sender_dir)):
            assert time.monotonic()<until
            time.sleep(.02)
        env = dict(os.environ,TMUX=matrix.server_address,TMUX_BIN=str(matrix.tmux_binary),TMUX_RELAY_LOCK_ROOT=str(out/'locks'),CC_MSG_INBOX_ROOT=str(out/'inbox'),CC_MSG_SESSION=session,CC_MSG_WINDOW='lala',CODEX_SEND_SESSION=session,AGY_SEND_SESSION=session,RELAY_STARTED_MINUTES='.002')
        for key in ('CC_MSG_QUEUE_INTERNAL','CODEX_SEND_QUEUE_INTERNAL','AGY_SEND_QUEUE_INTERNAL','RELAY_MESSAGE_RECORD'):
            env.pop(key,None)
        for index in (1,2):
            command = [str(tools/'cc-msg.sh'),'execute task '+str(index)] if app=='claude' else [str(tools/('codex-send-to' if app=='codex' else 'agy-send-to')),'lala','execute task '+str(index)]
            request = sender_dir/('request-'+str(index)+'.json')
            request.write_text(json.dumps(dict(argv=command,env=env)))
            request.with_suffix('.ready').touch()
            until = time.monotonic()+25
            while not request.with_suffix('.result').exists():
                assert time.monotonic()<until
                time.sleep(.02)
            result = json.loads(request.with_suffix('.result').read_text())
            assert result['returncode']==0,result
            assert 'not started yet' in result['stdout'],result
            if app=='codex':
                assert 'is unbound: it cannot reply until bound' in result['stdout'],result
        until = time.monotonic()+20
        while not (sender_dir/'submitted.json').exists() or len(json.loads((sender_dir/'submitted.json').read_text()))<2:
            assert time.monotonic()<until,app
            time.sleep(.05)
        received = json.loads((target_dir/'submitted.json').read_text())
        alerts = json.loads((sender_dir/'submitted.json').read_text())
        preamble = 'Messages delivered here are tasks for you;'
        assert len(received)==2 and preamble in received[0],received
        assert (preamble in received[1]) == (app=='codex'),received
        assert all(line.startswith('sender ('+session+':sender) [') for line in received),received
        assert len(alerts)==2 and all('relay watch: target' in line for line in alerts),alerts
        wire = (target_dir/'wire.bin').read_bytes()
        assert wire.count(b'\r')+wire.count(b'\n')==2,'watch typed extra input to target'
        results.append(dict(app=app,deliveries=len(received),alerts=len(alerts),target_enter_count=2,unbound_repeat=app=='codex'))
        matrix.cleanup_session(session)
finally:
    matrix.close()
(out/'results.json').write_text(json.dumps(results,indent=2))
print('PASS native-shaped inert Claude/Codex/Agy public adapters: one preamble, default idle wakeups, unchanged labels, no extra target input; '+str(out))
