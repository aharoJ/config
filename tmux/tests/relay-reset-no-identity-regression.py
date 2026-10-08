#!/usr/bin/env python3
import pathlib
import subprocess

helper = pathlib.Path(__file__).resolve().parents[1] / 'tools/codex-new-chat'
text = helper.read_text()
function = text.split('new_finish_reset() {', 1)[1].split('\n}', 1)[0]
result = subprocess.run(['bash', '-c', 'release_relay_lock() { printf "released\\n"; }; new_finish_reset() {' + function + '\n}; new_finish_reset'], capture_output=True, text=True, check=True)
assert result.stdout == 'released\n'
assert 'relay-codex-source-probe' not in text
assert 'source binding verified' not in text
assert text.count('new_finish_reset') == 4
print('PASS reset completion releases lock without identity input or false binding claim')
