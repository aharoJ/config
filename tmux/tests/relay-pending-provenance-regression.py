#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('transport', ROOT / 'tests/relay-delivery-regression.py')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
output = Path(sys.argv[1]).resolve()
matrix = transport.Matrix(output)
tools = output / 'tools'
shutil.copytree(ROOT / 'tools', tools)
messages = ['older pending record', "fresh sender's assignment with unmatched quote"]
try:
    session, window, directory = matrix.start('cc-msg.sh', 'pending-quote', mode='operator-draft', width=420)
    _, env = matrix.command('cc-msg.sh', session, window, '', {'CC_MSG_INBOX_ROOT': str(output / 'inbox')})
    for key in ('CC_MSG_QUEUE_INTERNAL', 'CODEX_SEND_QUEUE_INTERNAL', 'AGY_SEND_QUEUE_INTERNAL', 'RELAY_MESSAGE_RECORD'):
        env.pop(key, None)
    env['PATH'] = '/bin:' + env['PATH']
    request = output / 'request.json'
    request.write_text(json.dumps(dict(env=env, messages=messages, queue=str(tools / 'cc-msg-queue'))))
    driver = output / 'driver.py'
    driver.write_text('import json,pathlib,subprocess,sys,time\np=pathlib.Path(sys.argv[1]);d=json.loads(p.read_text());r=[]\nfor text in d["messages"]:\n q=subprocess.run([sys.executable,d["queue"],text],env=d["env"],text=True,capture_output=True);r.append(dict(exit=q.returncode,output=q.stdout,error=q.stderr))\np.with_suffix(".results").write_text(json.dumps(r))\nwhile not p.with_suffix(".stop").exists(): time.sleep(.1)\n')
    source = output / 'actor.c'
    source.write_text('#include <sys/wait.h>\n#include <unistd.h>\nint main(int n,char **v){if(n<2)return 1;pid_t p=fork();if(p<0)return 1;if(!p){execvp(v[1],v+1);_exit(127);}int s;waitpid(p,&s,0);return 0;}\n')
    binary = output / 'claude'
    subprocess.run(['cc', str(source), '-o', str(binary)], check=True, capture_output=True)
    sender_window = 'sender'
    matrix.tmux('new-window', '-d', '-t', '=' + session, '-n', sender_window, shlex.join(['exec', str(binary), sys.executable, str(driver), str(request)]))
    deadline = time.monotonic() + 40
    while not request.with_suffix('.results').exists():
        assert time.monotonic() < deadline, 'public queue sender timed out'
        time.sleep(.1)
    initial = json.loads(request.with_suffix('.results').read_text())
    assert [row['exit'] for row in initial] == [6, 6], initial
    assert not (directory / 'wire.bin').exists(), 'queued public calls wrote into draft'
    records = sorted((output / 'inbox').glob('*/*.json'), key=lambda p: json.loads(p.read_text())['created'])
    assert len(records) == 2
    assert [json.loads(p.read_text())['state'] for p in records] == ['queued', 'queued']
    target = '=' + session + ':=' + window
    for index, record in enumerate(records):
        matrix.tmux('send-keys', '-t', target, 'C-e', 'C-u')
        deadline = time.monotonic() + 40
        while json.loads(record.read_text())['state'] != 'delivered':
            data = json.loads(record.read_text())
            assert data['state'] in ('queued', 'attempting'), data
            assert time.monotonic() < deadline, data
            time.sleep(.1)
        submitted = json.loads((directory / 'submitted.json').read_text())
        expected = [f'{sender_window} ({session}:{sender_window}) [model/effort unverified]: ' + text for text in messages[:index+1]]
        assert submitted == expected, (submitted, expected)
    request.with_suffix('.stop').touch()
    (output / 'results.json').write_text(json.dumps(dict(initial=initial, submitted=submitted, records=[json.loads(p.read_text()) for p in records]), indent=2)+'\n')
finally:
    matrix.close()
print('PASS: older pending record plus fresh unmatched-quote public caller queued without input, then delivered exactly once in FIFO order on Bash 3.2')
