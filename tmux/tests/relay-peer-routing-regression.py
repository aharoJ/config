import json
from pathlib import Path
import runpy
import sys
import tempfile
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
guard = runpy.run_path(str(TOOLS / 'relay-route-guard'))
launcher = runpy.run_path(str(TOOLS / 'relay'))
source = dict(app='codex', session='new-swarm', window='whale-3', socket=dict(device=1,inode=2))
rows = [['%1','new-swarm','whale-3','','100','0'],['%2','new-project','blue-19','','200','0']]
g = guard['check'].__globals__
with patch.dict(g, live=lambda env, source:True, panes=lambda env:rows, pane_source=lambda env,row:dict(source,session=row[1],window=row[2])):
    for left,right in [(rows[0],rows[1]),(rows[1],rows[0])]:
        for sender in ('claude','codex','agy','gemini'):
            for recipient in ('claude','codex','agy','gemini'):
                with patch.dict(g, pane_source=lambda env,row:dict(source,app=recipient,session=row[1],window=row[2])):
                    assert guard['check']({},dict(source,app=sender,session=left[1],window=left[2]),right[1],right[2])
    calls=[]
    def live(env, value):
        calls.append(value)
        return len(calls) < 3
    with patch.dict(g,live=live):
        assert not guard['check']({},source,'new-project','blue-19')
with tempfile.TemporaryDirectory() as directory:
    path=Path(directory)/'legacy.json'
    path.write_text(json.dumps(dict(session='new-project',window='blue-19',watch_notification=True)))
    with patch.object(sys,'argv',['guard','--record',str(path),'--target-session','new-project','--target-window','blue-19']), patch.dict(g,record_caller=lambda *args:(_ for _ in ()).throw(AssertionError('legacy notification reached caller proof'))):
        try:
            guard['main']()
            raise AssertionError('legacy automatic notification accepted')
        except ValueError as error:
            assert 'automatic watch notifications were removed' in str(error)
lg=launcher['main'].__globals__
for args in (['relay','orcha','task'],['relay','new-project:blue-19','--watch','1','task']):
    with patch.object(sys,'argv',args),patch.dict(lg['GUARD'],bind=lambda *args:source,check=lambda *args:(_ for _ in ()).throw(AssertionError('removed launcher path reached routing'))):
        try:
            launcher['main']()
            raise AssertionError('removed launcher path accepted')
        except ValueError:
            pass
print('PASS 32 symmetric vendor/address routes, generation race, legacy notification refusal and removed launcher paths; no terminal input')
