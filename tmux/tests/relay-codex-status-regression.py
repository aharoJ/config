#!/usr/bin/env python3
from pathlib import Path
import runpy
import re

m = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/relay-codex-source-probe'))
thread = '00000000-0000-4000-8000-000000000001'
card = '\x1b[35m/status\x1b[39m\n\n  \x1b[38;2;99;168;248m>_ \x1b[1m\x1b[39mOpenAI Codex\x1b[0;2m (v0.160.1)\x1b[0m\n\n\x1b[2m  Server:                     \x1b[0mLocal background server\n\x1b[2m  Session:                    \x1b[0m' + thread + '\n\n› \n'
assert m['status_cards'](card) == [(2, thread)]
assert m['status_cards'](card.replace('v0.160.1', 'v0.160.0')) == [(2, thread)]
for rejected in [re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', card), card.replace('35m/status', '0m/status'), card.replace('/status', 'quoted status'), card.replace('v0.160.1', 'v0.160.2'), card.replace('Local background server', 'unknown'), card.replace('Session:', 'Session:\x1b]8;;https://example.test\x07'), card.replace('\n\n› ', '\n\x1b[2m  Session:                    \x1b[0m' + thread + '\n\n› ')]:
    assert not m['status_cards'](rejected), repr(rejected)
print('PASS native local status card; plain, reset-only, unrequested, unknown, OSC and duplicate session rows refuse')
