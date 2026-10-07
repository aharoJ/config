#!/usr/bin/env python3
import pathlib
import runpy
import subprocess
from unittest.mock import patch

tools = pathlib.Path(__file__).resolve().parents[1] / 'tools'
guard = runpy.run_path(str(tools / 'relay-route-guard'))
source = {'version': 2, 'app': 'codex', 'pane': '%1'}
for kind, alive, accepts in [('operator', True, True), ('operator', False, False), ('native-status', True, False), (None, True, False)]:
    data = {'bindings': {'thread': source}, 'proofs': {'thread': {'kind': kind}}}
    with patch.dict(guard['automatic_source'].__globals__, source_bindings=lambda: data, live=lambda env, bound: alive), patch('subprocess.run', side_effect=AssertionError('identity discovery invoked subprocess')):
        try:
            bound = guard['automatic_source']({}, 'thread')
        except ValueError:
            assert not accepts
        else:
            assert accepts and bound == dict(source, thread_id='thread')
for arguments in ([], ['--bind', 'config:codex'], ['--act', 'missing', 'empty']):
    result = subprocess.run([str(tools / 'relay-codex-source-probe'), *arguments], input=b'{}', capture_output=True)
    assert result.returncode == 1 and b'no pane input' in result.stderr
print('P0 identity entry points: no subprocess discovery or pane input; PASS')
