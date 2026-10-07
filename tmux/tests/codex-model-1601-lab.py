#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=False)
server = 'ccmsg-lab-private-model1601-' + str(os.getpid())
def tmux(*args):
    return subprocess.check_output(['tmux', '-L', server, '-f', '/dev/null', *args], text=True)
results = []
try:
    for name, tool, scenario, expected in [('model-terra-to-sol', 'codex-model', 'model', 0), ('new-chat-restore-terra', 'codex-new-chat', 'reset', 0), ('model-owned-draft', 'codex-model', 'draft', 5)]:
        case = output / name
        case.mkdir()
        shutil.copytree(ROOT / 'tools', case / 'tools')
        if tool == 'codex-new-chat':
            (case / 'tools/relay-route-guard').write_text("#!/bin/sh\nprintf '%s\\n' '{}'\n")
        actor = case / '@openai/codex/bin/codex.js'
        actor.parent.mkdir(parents=True)
        shutil.copy2(ROOT / 'tests/fixtures/codex-model-1601-tui.js', actor)
        log = case / 'input.jsonl'
        log.touch()
        command = shlex.join(['node', str(actor), '~/model-lab/' + name, str(log), scenario])
        tmux('new-session', '-d', '-s', 'lab', '-n', 'codex', '-x', '200', '-y', '50', '-c', str(case), 'exec ' + command)
        for _ in range(50):
            capture = tmux('capture-pane', '-p', '-e', '-t', 'lab:codex')
            if 'Ask Codex' in capture or 'owned draft' in capture:
                break
            time.sleep(.1)
        (case / 'before.ansi').write_text(capture)
        env = dict(os.environ, TMUX=tmux('display-message', '-p', '-t', 'lab:codex', '#{socket_path},#{pid},0').strip(), CODEX_SEND_SESSION='lab', TMPDIR=str(case), TMUX_RELAY_LOCK_ROOT=str(case / 'locks'))
        args = [str(case / 'tools' / tool)] + (['lab', 'codex', 'gpt-6.1-sol', 'low'] if tool == 'codex-model' else ['codex'])
        p = subprocess.run(args, env=env, capture_output=True, text=True, timeout=90)
        after = tmux('capture-pane', '-p', '-e', '-t', 'lab:codex')
        (case / 'after.ansi').write_text(after)
        (case / 'stdout').write_text(p.stdout)
        (case / 'stderr').write_text(p.stderr)
        inputs = log.read_text().splitlines()
        typed = ''.join(json.loads(line) for line in inputs)
        desired = 'GPT-6.1-Sol low' if tool == 'codex-model' else 'GPT-5.6-Terra max'
        passed = p.returncode == expected and (not inputs if scenario == 'draft' else desired in after and 'Select Model and Effort' not in after and 'Context 0% used' in after)
        if scenario != 'draft':
            passed = passed and typed.count('/model') == 1 and typed.endswith('s') and ('for this session only' in after)
            if scenario == 'reset':
                passed = passed and typed.count('/new') == 1
        results.append({'case': name, 'passed': passed, 'exit': p.returncode, 'inputs': inputs})
        print(name, 'PASS' if passed else 'FAIL', p.returncode, p.stderr[-500:], flush=True)
        tmux('kill-session', '-t', 'lab')
finally:
    subprocess.run(['tmux', '-L', server, 'kill-server'], capture_output=True)
    (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
assert all(row['passed'] for row in results), results
