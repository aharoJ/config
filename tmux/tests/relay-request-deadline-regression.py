from pathlib import Path
import subprocess
import sys

output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True,exist_ok=True)
root = Path(__file__).resolve().parents[1]
stub = output/'timeout-stub'
stub.write_text('#!/bin/sh\nprintf "%s\\n" "$3"\nexit 124\n')
stub.chmod(0o755)
for name in ['cc-msg.sh','codex-send','codex-send-to','agy-send-to']:
    text = (root/'tools'/name).read_text()
    function = text[text.index('request() {'):]
    function = function[:function.index('\n}\n')+3]
    command = function+'\nrequest if-shell\necho $?\nrequest list-panes\necho $?\n'
    env = dict(TIMEOUT_BIN=str(stub),TMUX_BIN='tmux',TMUX_TIMEOUT_SECONDS='1',TMUX_TIMEOUT_KILL_AFTER='1')
    result = subprocess.run(['bash','-c',command],env=env,capture_output=True,text=True,check=True)
    assert result.stdout.splitlines() == ['15','76','1','75'],(name,result)
print('PASS: eight request deadlines and timeout classifications')
