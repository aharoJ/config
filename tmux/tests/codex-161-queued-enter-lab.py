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
results = []
for name, mode, expected in [('submit-once', 'codex161-native', 'delivered'), ('draft-after-paste', 'codex161-extra', 'unknown')]:
    folder = output / name
    matrix = transport.Matrix(folder)
    tools = folder / 'tools'
    shutil.copytree(ROOT / 'tools', tools)
    try:
        session, window, directory = matrix.start('codex-send-to', name, mode=mode, width=200, height=50)
        _, env = matrix.command('codex-send-to', session, window, '', {'CC_MSG_INBOX_ROOT': str(folder / 'inbox')})
        for key in ('CC_MSG_QUEUE_INTERNAL', 'CODEX_SEND_QUEUE_INTERNAL', 'AGY_SEND_QUEUE_INTERNAL', 'RELAY_MESSAGE_RECORD'):
            env.pop(key, None)
        request = folder / 'request.json'
        request.write_text(json.dumps(dict(env=env, queue=str(tools / 'cc-msg-queue'), window=window)))
        driver = folder / 'driver.py'
        driver.write_text('import json,pathlib,subprocess,sys,time\np=pathlib.Path(sys.argv[1]);d=json.loads(p.read_text());r=subprocess.run([sys.executable,d["queue"],"--codex-to",d["window"],"native 0.161 queued composer receipt"],env=d["env"],text=True,capture_output=True);p.with_suffix(".result").write_text(json.dumps(dict(code=r.returncode,out=r.stdout,err=r.stderr)))\nwhile not p.with_suffix(".stop").exists():time.sleep(.1)\n')
        source = folder / 'actor.c'
        source.write_text('#include <sys/wait.h>\n#include <unistd.h>\nint main(int n,char **v){pid_t p=fork();if(!p){execvp(v[1],v+1);_exit(127);}int s;waitpid(p,&s,0);return 0;}\n')
        actor = folder / 'claude'
        subprocess.run(['cc', str(source), '-o', str(actor)], check=True, capture_output=True)
        matrix.tmux('new-window', '-d', '-t', '=' + session, '-n', 'sender', shlex.join(['exec', str(actor), sys.executable, str(driver), str(request)]))
        until = time.monotonic() + 30
        while not request.with_suffix('.result').exists():
            assert time.monotonic() < until
            time.sleep(.1)
        initial = json.loads(request.with_suffix('.result').read_text())
        assert initial['code'] == 6, initial
        assert not (directory / 'wire.bin').exists()
        record = next((folder / 'inbox').glob('*/*.json'))
        matrix.tmux('send-keys', '-t', '=' + session + ':=' + window, 'C-u')
        until = time.monotonic() + 40
        while True:
            data = json.loads(record.read_text())
            if data['state'] not in ('queued', 'attempting'):
                break
            assert time.monotonic() < until, data
            time.sleep(.1)
        assert data['state'] == expected, data
        wire = (directory / 'wire.bin').read_bytes()
        entered = wire.count(b'\r') + wire.count(b'\n')
        submitted = json.loads((directory / 'submitted.json').read_text()) if (directory / 'submitted.json').exists() else []
        assert entered == (1 if expected == 'delivered' else 0), wire
        assert len(submitted) == (1 if expected == 'delivered' else 0), submitted
        if expected == 'unknown':
            time.sleep(6)
            assert (directory / 'wire.bin').read_bytes() == wire
            assert json.loads(record.read_text())['state'] == 'unknown'
        results.append(dict(case=name, state=data['state'], code=data['code'], enter_count=entered, submitted=submitted))
    finally:
        matrix.close()
(output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
print('PASS native 0.161 capture-derived queued codex-send-to: exact-once Enter; changed draft unknown, zero Enter and no replay')
