#!/usr/bin/env python3
# path: ~/.config/tmux/tests/codex-new-chat-lab.py
# description: Red-team codex-new-chat against a fake Codex TUI on a private tmux server.
# date: 2026-10-03
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
TUI = ROOT / 'tests/fixtures/codex-new-fake-tui.js'
BASE = pathlib.Path.home() / 'desk/lab' / f'codex-new-chat-{os.getpid()}'
SERVER = f'ccmsg-lab-private-{os.getpid()}'
STUB = '#!/bin/sh\n[ $# -eq 3 ] && [ "$3" != lab-proof ] && exit 1\n[ $# -eq 2 ] && echo lab-proof\nexit 0\n'
results = []


def tmux(*args, check=True):
    return subprocess.run(['tmux', '-L', SERVER, '-f', '/dev/null', *args], capture_output=True, text=True, check=check).stdout


def case(name, start='fresh', runs=1, width=200, session='lab', expect=(0,), copy=False, command=None,
         parallel=False, inputs='none', final='fresh', zsh=False):
    lab = BASE / name
    (lab / 'proj').mkdir(parents=True)
    shutil.copytree(ROOT / 'tools', lab / 'tools')
    (lab / 'tools/codex-target-guard').write_text(STUB)
    (lab / 'tools/relay-codex-source-probe').write_text('#!/bin/sh\nexit 0\n')
    (lab / 'tools/relay-codex-source-probe').chmod(0o700)
    (lab / 'tools/relay-route-guard').write_text('#!/bin/sh\nprintf \'%s\\n\' \'{}\'\n')
    log = lab / 'input.log'
    log.touch()
    shown = f'~/desk/lab/{BASE.name}/{name}/proj'
    cmd = command or f"exec node {TUI} {start} '{shown}' {log}"
    tmux('new-session', '-d', '-s', 'lab', '-n', 'codex', '-x', str(width), '-y', '50', '-c', str(lab / 'proj'), cmd)
    time.sleep(1)
    if copy:
        tmux('copy-mode', '-t', 'lab:codex')
    socket = tmux('display', '-p', '#{socket_path}').strip()
    env = dict(os.environ, TMUX=f'{socket},1,0', CODEX_SEND_SESSION=session)
    tool = str(lab / 'tools/codex-new-chat')
    argv = ['zsh', '-c', 'S=lab; CODEX_SEND_SESSION="$S:codex" ' + tool + ' codex'] if zsh else [tool, 'codex']
    if parallel:
        procs = [subprocess.Popen(argv, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) for _ in range(runs)]
        outs = [(p.wait(), p.stdout.read().strip()) for p in procs]
    else:
        outs = []
        for _ in range(runs):
            r = subprocess.run(argv, env=env, capture_output=True, text=True)
            outs.append((r.returncode, (r.stdout + r.stderr).strip()))
    time.sleep(0.3)
    screen = tmux('capture-pane', '-p', '-t', 'lab:codex')
    sent = [json.loads(x) for x in log.read_text().splitlines()]
    tmux('kill-session', '-t', 'lab')
    codes = [c for c, _ in outs]
    ok = all(c in expect for c in codes) and 'WORKTREE' not in screen and 'WORKTREE' not in sent
    if inputs == 'none':
        ok = ok and not sent
    elif inputs == 'enter':
        ok = ok and ''.join(sent) == '\r'
    elif inputs == 'reset':
        ok = ok and ''.join(sent).count('/new') == 1
    if final == 'fresh':
        ok = ok and 'Context 0% used' in screen and 'earlier reply' not in screen
    if parallel:
        ok = ok and codes.count(0) >= 1
    results.append(dict(case=name, ok=ok, exits=codes, inputs=sent, outputs=[o.splitlines()[-1] if o else '' for _, o in outs]))


try:
    case('fresh-x3', runs=3)
    case('used-x3', start='used', runs=3, inputs='reset')
    case('picker-x2', start='menu', runs=2, inputs='enter')
    case('picker-option-2', start='menu2', expect=(5,), final=None)
    case('picker-flipping', start='flip', runs=3, expect=(0, 4, 5), inputs='any', final=None)
    case('draft-at-0pct', start='draft', expect=(5,), final=None)
    case('working', start='working', expect=(5,), final=None)
    case('working-line-blinks', start='blink', runs=3, expect=(5,), final=None)
    case('compacting', start='compacting', expect=(5,), final=None)
    case('stale-0pct-footer', start='stale', expect=(1,), final=None)
    case('narrow-wrapped', start='used', width=60, expect=(1, 5), final=None)
    case('copy-mode-fresh', copy=True, expect=(2,), final=None)
    case('copy-mode-picker', start='menu', copy=True, expect=(2,), final=None)
    case('non-codex', command='sleep 600', expect=(1,), final=None)
    case('missing-session', session='nope', expect=(1,), final=None)
    case('parallel-used-x3', start='used', runs=3, parallel=True, expect=(0, 5), inputs='reset')
    case('parallel-picker-x3', start='menu', runs=3, parallel=True, expect=(0, 5), inputs='enter')
    case('zsh-S-codex', zsh=True, expect=(1,), final=None)
finally:
    subprocess.run(['tmux', '-L', SERVER, 'kill-server'], capture_output=True)
    if BASE.exists():
        subprocess.run(['trash', str(BASE)])
print(json.dumps(results, ensure_ascii=False, indent=1))
failed = [r['case'] for r in results if not r['ok']]
print(f'codex new chat lab: {len(results)} cases, {len(failed)} failed {failed}')
sys.exit(1 if failed else 0)
