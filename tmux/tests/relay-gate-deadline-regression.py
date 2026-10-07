import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('transport',root/'tests/relay-delivery-regression.py')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
output = Path(sys.argv[1]).resolve()
matrix = transport.Matrix(output)
tools = output/'tools'
shutil.copytree(root/'tools',tools)
original = matrix.command
try:
    for name, delay, status, expected in [('slow-allow',1.4,0,0),('slow-deny',1.4,1,5),('guard-deadline',9,0,5)]:
        guard = tools/'relay-route-guard'
        guard.write_text('#!/usr/bin/env python3\nimport os,subprocess,time,sys\nparent=subprocess.check_output(["ps","-p",str(os.getppid()),"-o","comm="],text=True).strip()\nif "timeout" in parent:\n time.sleep('+str(delay)+')\n sys.exit('+str(status)+')\nprint("{}")\n')
        guard.chmod(0o755)
        def command(relay, session, window, payload, extra=None, source=True):
            argv, env = original(relay,session,window,payload,extra,source=source)
            argv[0] = str(tools/relay)
            return argv,env
        matrix.command = command
        matrix.case('cc-msg.sh',name,code=expected)
finally:
    matrix.close()
assert all(row['passed'] for row in matrix.results),matrix.results
assert 'unresponsive' not in ''.join(row['stderr'] for row in matrix.results)
print('PASS: slow guard allows once; delayed denial/deadline produces zero input without false server-unresponsive')
