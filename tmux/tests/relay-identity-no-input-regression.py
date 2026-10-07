#!/usr/bin/env python3
import pathlib
import runpy
import subprocess
from unittest.mock import patch

tools = pathlib.Path(__file__).resolve().parents[1] / 'tools'
guard = runpy.run_path(str(tools / 'relay-route-guard'))
with patch('subprocess.run', side_effect=AssertionError('identity discovery invoked subprocess')):
    try:
        guard['automatic_source']({}, 'thread')
    except ValueError as error:
        assert 'read-only' in str(error)
    else:
        raise AssertionError('disabled discovery did not refuse')
for arguments in ([], ['--bind', 'config:codex'], ['--act', 'missing', 'empty']):
    result = subprocess.run([str(tools / 'relay-codex-source-probe'), *arguments], input=b'{}', capture_output=True)
    assert result.returncode == 1 and b'no pane input' in result.stderr
print('P0 identity entry points: no subprocess discovery or pane input; PASS')
