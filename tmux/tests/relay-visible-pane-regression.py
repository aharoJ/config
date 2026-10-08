#!/usr/bin/env python3
"""Real split-window focus race: only read operations address source panes."""
import pathlib
import os
import runpy
import shlex
import subprocess
import time

module = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'tools/relay-visible-source'))
socket = 'ccmsg-lab-private-visible-' + str(os.getpid())


def tmux(*args):
    result = subprocess.run(['tmux','-L',socket,'-f','/dev/null',*args],capture_output=True,text=True,timeout=3)
    if result.returncode:
        raise ValueError(result.stderr)
    return result.stdout.strip()


def actor(text):
    screen = '› ' + text + '\n\n• Finished\n\n› Ask Codex to do anything\n'
    return 'printf %s ' + shlex.quote(screen) + '; exec cat'


try:
    a = tmux('new-session','-d','-s','fixture','-n','codex','-x','100','-y','30','-P','-F','#{pane_id}',actor('pane A distinct turn'))
    b = tmux('split-window','-d','-t',a,'-P','-F','#{pane_id}',actor('pane B distinct turn'))
    deadline = time.monotonic() + 3
    while 'pane A distinct turn' not in tmux('capture-pane','-p','-t',a):
        assert time.monotonic() < deadline
        time.sleep(.02)
    source = dict(pane=a,session='fixture',window='codex')
    commands = []
    def run(env,*args):
        commands.append(args)
        assert args[0] == 'tmux' and args[1] in ('display-message','capture-pane')
        assert args[args.index('-t') + 1] == a
        result = tmux(*args[1:])
        if args[1] == 'display-message':
            # Deliberately switch active pane after metadata, before capture.
            tmux('select-pane','-t',b)
        return result
    assert module['capture']({},source,run) == 'pane A distinct turn'
    assert tmux('display-message','-p','-t','=fixture:=codex','#{pane_id}') == b
    assert commands[0][1] == commands[-1][1] == 'display-message'
    tmux('resize-window','-t','=fixture:=codex','-x','40','-y','24')
    assert module['capture']({},source,run) == 'pane A distinct turn'
    # Old prompts exist only in scrollback: never request historical capture.
    stale = actor('old scrollback turn').split('; exec cat')[0] + '; printf %s ' + shlex.quote('\n' * 80 + '\033[2J\033[H› Ask Codex to do anything\n') + '; exec cat'
    c = tmux('new-window','-d','-t','fixture','-n','scrollback','-P','-F','#{pane_id}',stale)
    direct = lambda env,*args:tmux(*args[1:])
    time.sleep(.05)
    try:
        module['capture']({},dict(pane=c,session='fixture',window='scrollback'),direct)
    except ValueError:
        pass
    else:
        raise AssertionError('scrollback was promoted to current evidence')
    alt = 'printf %s ' + shlex.quote('\033[?1049h› alternate screen turn\n\n• Finished\n\n› Ask Codex to do anything\n') + '; exec cat'
    d = tmux('new-window','-d','-t','fixture','-n','alternate','-P','-F','#{pane_id}',alt)
    time.sleep(.05)
    try:
        module['capture']({},dict(pane=d,session='fixture',window='alternate'),direct)
    except ValueError:
        pass
    else:
        raise AssertionError('alternate screen was accepted')
    print('PASS real private split-window focus changes, resize, scrollback and alternate-screen refusals; zero input commands')
finally:
    stopped = subprocess.run(['tmux','-L',socket,'kill-server'],capture_output=True,text=True,timeout=3)
    proof = subprocess.run(['tmux','-L',socket,'list-sessions'],capture_output=True,text=True,timeout=3)
    assert proof.returncode == 1 and ('no server running' in proof.stderr or 'No such file' in proof.stderr)
