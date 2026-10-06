import importlib.util
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
(tools/'relay-route-guard').write_text('#!/bin/sh\nprintf "%s\\n" "{}"\n')
(tools/'relay-sender-label').write_text('#!/bin/sh\nprintf "%s\\n" "%99999 rp-schema codex 101 codex"\n')
try:
    session,window,directory = matrix.start('cc-msg.sh','synthetic-rp-schema-label')
    proxy = output/'tmux-identity-fixture'
    proxy.write_text('#!/usr/bin/env bash\nif [[ "$*" = *%99999* ]] && [ "$1" = display-message ]; then printf "%s\\n" "%99999 rp-schema codex 101 0"; else exec '+str(matrix.tmux_binary)+' "$@"; fi\n')
    proxy.chmod(0o755)
    argv,env = matrix.command('cc-msg.sh',session,window,'allowance lab probe',{'TMUX_BIN':str(proxy)})
    argv[0] = str(tools/'cc-msg.sh')
    result = subprocess.run(argv,env=env,capture_output=True,text=True,timeout=30)
    matrix.record('cc-msg.sh','synthetic-rp-schema-label',result,0,directory,'codex (rp-schema:codex): allowance lab probe')
finally:
    matrix.close()
assert all(row['passed'] for row in matrix.results),matrix.results
print('PASS: exact worker label submitted once on private terminal with explicitly synthetic source identity and routing mocks')
