#!/usr/bin/env python3
import argparse
import concurrent.futures
import json
import os
import shutil
import signal
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
CASES = ['relay-reset-no-identity-regression.py', 'relay-identity-no-input-regression.py', 'queue-route-regression.py',
         'relay-route-guard-regression.py', 'relay-native-argv-regression.py',
         'codex-footer-compat-regression.py', 'codex-new-guard-regression.py',
         'codex-target-guard-regression.py', 'relay-request-deadline-regression.py']
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--workers', type=int, default=4)
parser.add_argument('--private-tmux', action='store_true')
args = parser.parse_args()
output = args.output.resolve()
if not output.is_relative_to(Path.home() / 'desk') or not 1 <= args.workers <= 8:
    parser.error('output must be under ~/desk and workers in 1..8')
output.mkdir(parents=True, exist_ok=True)

if args.private_tmux:
    CASES = ['relay-shell-quote-regression.py', 'relay-paste-row-regression.py', 'relay-duplicate-enter-regression.py']

def execute(case):
    directory = output / Path(case).stem
    directory.mkdir(exist_ok=True)
    env = dict(os.environ, TMPDIR=str(directory))
    if args.private_tmux:
        binary = directory / 'bin'
        binary.mkdir(exist_ok=True)
        sockets = Path.home() / 'desk/lab' / ('rn-s-' + str(os.getpid()))
        sockets.mkdir(exist_ok=True)
        wrapper = binary / 'tmux'
        wrapper.write_text('#!' + sys.executable + '\nimport os,sys,pathlib,hashlib\na=sys.argv[1:]\nif "-L" in a:\n i=a.index("-L");name=a[i+1]\n if not name or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for c in name):sys.exit(1)\n a[i:i+2]=["-S",str(pathlib.Path(' + repr(str(sockets)) + ')/ (hashlib.sha256(name.encode()).hexdigest()[:16]+".sock"))]\nos.execv(' + repr(shutil.which('tmux')) + ',["tmux",*a])\n')
        wrapper.chmod(0o700)
        env['PATH'] = str(binary) + os.pathsep + env['PATH']
    started = time.monotonic()
    try:
        command = [sys.executable, str(ROOT / case)]
        if case == 'relay-request-deadline-regression.py':
            command.append(str(directory))
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   text=True, start_new_session=True)
        try:
            stdout, stderr = process.communicate(timeout=60)
            code = process.returncode
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                stdout, stderr = process.communicate(timeout=1)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                stdout, stderr = process.communicate()
            code = 124
    except OSError as error:
        code, stdout, stderr = 125, '', str(error)
    (directory / 'stdout.log').write_text(stdout)
    (directory / 'stderr.log').write_text(stderr)
    return dict(case=case, exit=code, seconds=round(time.monotonic()-started, 3))

started = time.monotonic()
with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
    results = list(pool.map(execute, CASES))
receipt = dict(workers=args.workers, seconds=round(time.monotonic()-started, 3), results=results,
               scope='Private tmux fast tier' if args.private_tmux else 'Fast logic tier; full matrix remains required before install')
(output / 'results.json').write_text(json.dumps(receipt, indent=2)+'\n')
print(json.dumps(receipt, indent=2))
sys.exit(any(row['exit'] for row in results))
