#!/usr/bin/env python3
# path: ~/.config/tmux/tests/codex-target-guard-regression.py
# description: Verify foreground ancestry and stable Codex entry-point binding.
# patched: reject unrelated, background, ambiguous and changed process identities
# date: 2026-10-06
import pathlib
import runpy
from unittest.mock import patch

guard = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'tools/codex-target-guard'))
snapshot = guard['snapshot']
namespace = snapshot.__globals__
identity = ['%1', '10', 'node', '/dev/ttys099', '0']
base = '10 1 10 20 fish\n20 10 20 20 node\n21 20 20 20 codex\n'
checks = 0


def check(table, apps, good, alternate=None, args='Thu Oct 2 node /installed/@openai/codex/bin/codex.js', applications=('codex',)):
    global checks
    states = iter([identity, alternate or identity])
    label = dict(namespace['LABEL'])
    label['ps'] = lambda *a: table if a[0] == '-t' else args
    label['app'] = lambda pid, command: apps.get(pid, '')
    with patch.dict(namespace, LABEL=label, query=lambda *a: next(states)):
        try:
            value = snapshot('/socket', '%1', applications)
        except ValueError:
            assert not good
        else:
            assert good and len(value) == 64
    checks += 1
    return value if good else None


original = check(base, {20: 'codex'}, True)
check(base, {20: ''}, False)
check(base.replace('20 10 20 20', '20 1 20 20'), {20: 'codex'}, False)
check(base.replace('20 10 20 20', '20 10 30 20'), {20: 'codex'}, False)
check(base.replace('10 1 10 20', '10 1 10 -1'), {20: 'codex'}, False)
check(base.replace('10 1 10 20 fish\n', ''), {20: 'codex'}, False)
check(base + '22 10 20 20 node\n', {20: 'codex', 22: 'codex'}, False)
check(base, {20: 'codex'}, False, ['%1', '10', 'fish', '/dev/ttys099', '0'])
check(base.replace('20 10', '20 21').replace('21 20', '21 20'), {20: 'codex'}, False)
assert check(base, {20: 'codex'}, True, args='different process start') != original
assert check(base.replace('20 10', '30 10').replace('21 20', '21 30'), {30: 'codex'}, True) != original
check(base, {20: 'agy'}, True, applications=('agy', 'gemini'))
check(base, {20: 'gemini'}, True, applications=('agy', 'gemini'))
check(base, {20: 'codex'}, False, applications=('agy', 'gemini'))
check(base, {20: 'claude'}, False)
print(f'Codex target guard: {checks} checks PASS')
