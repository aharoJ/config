#!/usr/bin/python3
"""Delivery authority: no server/session destruction or process signaling.

The default server is bound by socket identity and kernel generation, not a
fixture lease. Other sockets still require the existing signed fixture lease.
"""
import json
import os
from pathlib import Path
import re
import runpy
import shlex
import stat
import subprocess
import sys

TMUX = '/opt/homebrew/bin/tmux'
DEFAULT = Path('/private/tmp/tmux-%d/default' % os.geteuid())


def validate(args, nested=False):
    if not nested and len(args) == 5 and args[0:2] == ['set-buffer', '-b'] and re.fullmatch(r'relay-[a-f0-9]{32}', args[2]) and args[3] == '--':
        if '\n' in args[4] or '\r' in args[4]:
            raise ValueError('delivery command refused')
        return
    if not args or any(any(token in arg for token in ('#(', '#{E:', '#{T:', '\n', '\r')) for arg in args):
        raise ValueError('delivery command refused')
    verb = args[0]
    if verb == 'if-shell' and len(args) == 7 and args[1:3] == ['-F', '-t'] and re.fullmatch(r'%\d+', args[3]):
        for branch in args[5:]:
            lexer = shlex.shlex(branch, posix=True, punctuation_chars=';')
            lexer.whitespace_split = True
            lexer.commenters = ''
            command = []
            for word in lexer:
                if word == ';':
                    validate(command, True)
                    command = []
                else:
                    command.append(word)
            validate(command, True)
        return
    if verb == 'display-message' and ((len(args) == 3 and args[1] == '-p') or
                                    (len(args) == 5 and args[1:3] == ['-p', '-t'] and re.fullmatch(r'%\d+', args[3]))):
        return
    if not nested and verb == 'list-panes' and len(args) == 4 and args[1:3] == ['-a', '-F']:
        return
    if not nested and verb == 'capture-pane' and len(args) == 5 and args[1:4] == ['-p', '-e', '-t'] and re.fullmatch(r'%\d+', args[4]):
        return
    if nested and verb == 'paste-buffer' and len(args) == 5 and args[1] == '-b' and re.fullmatch(r'relay-[a-f0-9]{32}', args[2]) and args[3] == '-t' and re.fullmatch(r'%\d+', args[4]):
        return
    if nested and verb == 'send-keys' and len(args) == 4 and args[1] == '-t' and re.fullmatch(r'%\d+', args[2]) and args[3] == 'Enter':
        return
    raise ValueError('delivery command refused')


def attest(path):
    path = Path(path)
    guard = runpy.run_path(str(Path(__file__).with_name('cleanup_guard.py')))
    if path != DEFAULT:
        return guard['attest'](str(path))
    before = path.lstat()
    if not stat.S_ISSOCK(before.st_mode) or before.st_uid != os.geteuid() or path.resolve() != path:
        raise ValueError('default socket refused')
    # No timeout path that could signal a process. The Rust owner has a bounded
    # observation deadline and retains an unresolved result if a command hangs.
    result = subprocess.run([TMUX, '-S', str(path), 'display-message', '-p', '#{pid}'], capture_output=True, check=True)
    pid = int(result.stdout)
    generation = guard['generation'](pid)
    after = path.lstat()
    if (before.st_dev, before.st_ino) != (after.st_dev, after.st_ino):
        raise ValueError('default socket changed')
    return dict(pid=pid, generation=generation, owner=pid,
                nonce='default-server:%d:%d:%s' % (before.st_dev, before.st_ino, generation),
                authority='delivery-only; not a signed fixture lease')


def run_tmux(argv, **kwargs):
    if len(argv) < 4 or argv[:2] != ['tmux', '-S']:
        raise ValueError('explicit socket required')
    validate(argv[3:])
    attest(argv[2])
    kwargs.pop('timeout', None)
    return subprocess.run([TMUX, *argv[1:]], **kwargs)


if __name__ == '__main__':
    try:
        if len(sys.argv) == 3 and sys.argv[1] == 'attest':
            print(json.dumps(attest(sys.argv[2])))
        elif len(sys.argv) > 5 and sys.argv[1:4] == ['run', 'tmux', '-S']:
            validate(sys.argv[5:])
            attest(sys.argv[4])
            os.execv(TMUX, [TMUX, *sys.argv[3:]])
        else:
            raise ValueError('delivery operation refused')
    except Exception:
        sys.exit(1)
