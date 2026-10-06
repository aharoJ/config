#!/usr/bin/env python3
import pathlib
import runpy
import subprocess
import sys

module = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'tools/relay-sender-label'))
arguments = ['', "unmatched ' quote", 'unmatched " quote', 'trailing\\', 'space in argument', '$(false)', '`false`']
child = subprocess.Popen([sys.executable, '-c', 'import sys; sys.stdin.buffer.read()', *arguments], stdin=subprocess.PIPE)
try:
    actual = module['process_argv'](child.pid)
    assert actual[-len(arguments):] == arguments, actual
finally:
    child.communicate()
print('PASS: native argv preserves seven literal/empty boundaries')
