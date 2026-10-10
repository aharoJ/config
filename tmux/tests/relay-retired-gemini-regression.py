import os
import json
from pathlib import Path
import runpy
import sys
import tempfile
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
identity = runpy.run_path(str(TOOLS / 'relay-agent-identity'))
prove = identity['prove']
g = prove.__globals__
cases = 0
with tempfile.TemporaryDirectory() as directory:
    home = Path(directory)
    fnm = home / '.local/share/fnm/node-versions/v22.19.0/installation'
    brew = home / 'homebrew'
    for installation, node in ((fnm, fnm / 'bin/node'), (brew, Path('/opt/homebrew/Cellar/node/26.5.0/bin/node'))):
        root = installation / 'lib/node_modules'
        for relative in ('@google/gemini-cli/bundle/gemini.js', '@google/gemini-cli/dist/index.js'):
            entry = root / relative
            entry.parent.mkdir(parents=True, exist_ok=True)
            entry.write_text('')
            with patch.dict(g, HOME_ROOT=home, executable=lambda pid: node, node_root=lambda exe: root), patch.dict(g['LABEL'], process_argv=lambda pid: ['node', str(entry)]):
                assert prove(1) is None
            with patch.dict(g['LABEL']['app'].__globals__, process_argv=lambda pid: ['node', str(entry)]):
                assert g['LABEL']['app'](1, 'node') == ''
            cases += 1

guard = runpy.run_path(str(TOOLS / 'relay-route-guard'))
g = guard['check'].__globals__
source = dict(app='agy', actor=1, session='config', window='gemini', socket=dict(device=1, inode=2))
target = dict(source, actor=2, window='peer')
rows = [['%2', 'config', 'peer', '', '2', '0']]
with patch.dict(g, live=lambda *args: True, panes=lambda env: rows, pane_source=lambda *args: target):
    for sender, recipient, accepted in (('agy', 'agy', True), ('gemini', 'agy', False), ('agy', 'gemini', False), ('gemini', 'gemini', False)):
        with patch.dict(g['AGENT'], prove=lambda pid: dict(app=sender if pid == 1 else recipient, entrypoint=[None])):
            assert guard['check']({}, dict(source, app=sender), 'config', 'peer') == accepted
            cases += 1

launcher = runpy.run_path(str(TOOLS / 'relay'))
g = launcher['main'].__globals__
with patch.object(sys, 'argv', ['relay', 'config:peer', 'must not reach target']), patch.dict(g['GUARD'], bind=lambda *args: source, check=lambda *args: True, panes=lambda *args: rows, pane_source=lambda *args: dict(target, app='gemini')), patch.object(os, 'execve', side_effect=AssertionError('retired target reached transport')):
    try:
        launcher['main']()
    except ValueError as error:
        assert 'not a supported interactive agent' in str(error)
    else:
        raise AssertionError('retired target accepted')
    cases += 1

clear = runpy.run_path(str(TOOLS / 'relay-clear-draft'))
with tempfile.TemporaryDirectory() as directory, patch.object(sys, 'argv', ['relay-clear-draft', 'gemini', 'peer', '--expect', 'draft']), patch.object(clear['queue'], 'ROOT', Path(directory)), patch.object(clear['queue'], 'routing_source', return_value=source), patch.object(clear['queue'], 'identity', side_effect=AssertionError('retired clear kind reached target')):
    assert clear['main']() == 8
    records = [json.loads(p.read_text()) for p in Path(directory).glob('*/*.json')]
    assert len(records) == 1 and records[0]['state'] == 'clear-refused'
    cases += 1

print(f'PASS {cases} retired FNM/Homebrew bundle/dist identity, route, launcher and clear-draft checks; Agy Gemini seat remains authorized; no terminal input')
