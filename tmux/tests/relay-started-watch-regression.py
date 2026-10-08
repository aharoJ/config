#!/usr/bin/env python3
"""Deterministic watch lifecycle and once-only sender alerts."""
import json
import pathlib
import runpy
import tempfile
import time
import sys
from unittest.mock import patch

TOOLS = pathlib.Path(__file__).resolve().parents[1] / 'tools'
module = runpy.run_path(sys.argv[1] if len(sys.argv) > 1 else str(TOOLS / 'relay-started-watch'))
g = module['watch'].__globals__
root = pathlib.Path(tempfile.mkdtemp(prefix='relay-watch-', dir=pathlib.Path.home() / 'desk/lab'))
target = dict(socket='/private/socket', pane='%2')
sender = dict(socket='/private/socket', pane='%1')
source = dict(pane='%1', session='config', window='lala', app='codex', binding_epoch='original')
launches = []
def save(path, data):
    path.write_text(json.dumps(data))
queue = dict(ROOT=root, save=save, identity=lambda env: sender,
             launch_worker=lambda folder,path,data: launches.append((path,data)))
def record(name):
    path = root / (name + '.json')
    save(path, dict(id=name, state='delivered', watch_minutes=1, updated=time.time()-61,
                   watch_baseline='baseline', source=source, identity=target,
                   session='config', window='red', environment={'TMUX':'/private/socket,1,0'}))
    return path
with patch.dict(g, snapshot=lambda *args:'baseline'):
    path = record('idle')
    module['watch'](queue,path)
    module['watch'](queue,path)
assert len(launches) == 1
alert = launches[0][1]
assert alert['source'] == source and alert['window'] == 'lala'
assert alert['identity']['pane'] == '%1' and alert['identity']['pane'] != target['pane']
assert '\n' not in alert['message'] and not alert['operator']
with patch.dict(g, snapshot=lambda *args:'changed'):
    path = record('active')
    module['watch'](queue,path)
assert json.loads(path.with_suffix('.watch.json').read_text())['state'] == 'output-observed'
def unavailable(*args):
    raise ValueError('generation retired')
with patch.dict(g, snapshot=unavailable):
    path = record('retired')
    module['watch'](queue,path)
assert json.loads(path.with_suffix('.watch.json').read_text())['state'] == 'stopped'
assert len(launches) == 1
# Abrupt death before plan, after plan, after alert and after launch must leave
# one stable logical alert. Recovery must never rewind unknown delivery.
for boundary in ('before-plan','after-plan','after-alert','after-launch'):
    path = record('crash-' + boundary)
    receipt = path.with_suffix('.watch.json')
    before = len(launches)
    def crashing_save(destination, data):
        if boundary == 'before-plan' and destination == receipt:
            raise SystemExit('abrupt death')
        save(destination, data)
        if boundary == 'after-plan' and destination == receipt or boundary == 'after-alert' and destination.parent != root:
            raise SystemExit('abrupt death')
    def crashing_launch(folder, destination, data):
        launches.append((destination,data))
        if boundary == 'after-launch':
            save(destination, dict(data,state='unknown'))
            raise SystemExit('abrupt death after possible transport')
    with patch.dict(g, snapshot=lambda *args:'baseline'):
        try:
            module['watch'](dict(queue,save=crashing_save,launch_worker=crashing_launch),path)
        except SystemExit:
            pass
        module['watch'](queue,path)
        module['watch'](queue,path)
    records = [item for item in root.glob('config-lala-*/*.json') if path.stem in json.loads(item.read_text()).get('message','')]
    assert len(records) == 1, (boundary,records)
    assert len(launches) == before + 1, (boundary,launches)
    if boundary == 'after-launch':
        assert json.loads(records[0].read_text())['state'] == 'unknown'
calls = []
def read(command, **kwargs):
    calls.append(command)
    assert command[3] in ('display-message','capture-pane')
    assert command[command.index('-t')+1] == '%2'
    return type('Result',(),dict(returncode=0,stdout=b'%2|0|0\n' if command[3]=='display-message' else b'unchanged screen'))()
with patch.object(g['subprocess'], 'run', read):
    assert module['snapshot']({'identity':lambda env:target},{},target)
assert len(calls) == 3
try:
    module['snapshot']({'identity':lambda env:sender},{},target)
except ValueError:
    pass
else:
    raise AssertionError('generation replacement accepted')
print('PASS idle once-only sender alert; active/retired stop; exact-pane read-only observation')
