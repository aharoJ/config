#!/usr/bin/env python3
"""Standard delivery preamble, shared adapters and truthful status."""
import json
import pathlib
import runpy
import tempfile
from unittest.mock import patch

TOOLS = pathlib.Path(__file__).resolve().parents[1] / 'tools'
intro = runpy.run_path(str(TOOLS / 'relay-seat-introduction'))
queue = runpy.run_path(str(TOOLS / 'cc-msg-queue'))
root = pathlib.Path(tempfile.mkdtemp(prefix='relay-critical-',dir=pathlib.Path.home() / 'desk/lab'))
def save(path,data):
    path.write_text(json.dumps(data))
def data(folder,name,agent):
    folder.mkdir(exist_ok=True)
    record = folder / (name + '.json')
    item = dict(id=name, record=str(record), session='config',window='lala',identity={'pane':'%2'},message='execute task',agent=agent)
    save(record,item)
    return item
for agent in ('claude','codex','codex-to','agy'):
    folder = root / agent
    sent = []
    transport = lambda item,env:(sent.append(item['message']) or (0,'verified'))
    with patch.dict(intro['send'].__globals__, generation=lambda *args:'first'):
        assert intro['send']({'save':save},data(folder,'one',agent),{},transport)[0] == 0
        assert intro['send']({'save':save},data(folder,'two',agent),{},transport)[0] == 0
    with patch.dict(intro['send'].__globals__, generation=lambda *args:'reset'):
        intro['send']({'save':save},data(folder,'three',agent),{},transport)
    assert sent == [intro['PREAMBLE']+'\nexecute task','execute task',intro['PREAMBLE']+'\nexecute task']
    # Confirmed no-input refusal must not consume first-delivery introduction.
    with patch.dict(intro['send'].__globals__, generation=lambda *args:'busy'):
        intro['send']({'save':save},data(folder,'busy',agent),{},lambda *args:(5,'no input'))
        intro['send']({'save':save},data(folder,'retry',agent),{},transport)
    assert sent[-1].startswith(intro['PREAMBLE'])
    # Abrupt death after reservation never auto-replays a potentially pasted
    # introduction. Its receipt remains explicitly attempting, not delivered.
    def killed(*args):
        raise SystemExit('death after possible paste')
    with patch.dict(intro['send'].__globals__, generation=lambda *args:'crash'):
        try:
            intro['send']({'save':save},data(folder,'crash',agent),{},killed)
        except SystemExit:
            pass
        intro['send']({'save':save},data(folder,'later',agent),{},transport)
    assert sent[-1] == 'execute task'
    assert json.loads((folder/'.seat-state/introductions.json').read_text())['crash']['state'] == 'attempting'
record = root / 'status.json'
save(record,dict(id='status',state='delivered'))
assert queue['status_text'](record,json.loads(record.read_text())) == 'delivered: '+str(record)
folder = root/'unbound'
sent = []
def unbound(queue,item,env):
    item['_introduction_verified'] = False
    return 'same-process-with-unobservable-reset'
with patch.dict(intro['send'].__globals__, generation=unbound):
    for index in (1,2):
        intro['send']({'save':save},data(folder,str(index),'codex-to'),{},lambda item,env:(sent.append(item['message']) or (0,'verified')))
assert len(sent)==2 and all(line.startswith(intro['PREAMBLE']) for line in sent)
def unknown(*args):
    raise ValueError('current thread UUID unavailable')
with patch.dict(intro['send'].__globals__, generation=unknown):
    assert intro['send']({'save':save},data(folder,'unknown','codex-to'),{},lambda *args:(0,'verified'))[0]==0
print('PASS all shared adapters: first/repeat/reset introductions, no-input retry, uncertain lease; delivery status carries no task-progress assertion')
