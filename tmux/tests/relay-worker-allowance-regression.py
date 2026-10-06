import json,pathlib,runpy,shlex,sys,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1];TOOLS=ROOT/'tools';m=runpy.run_path(str(TOOLS/'relay-route-guard'));state=m['check'].__globals__;cases=[]
def test(name,actual,expected):
 assert actual==expected,(name,actual,expected)
 cases.append(name)
state['live']=lambda env,src:True
source={'app':'codex','actor':101,'session':'rp-schema','window':'codex'}
for app in ('claude','codex','agy','gemini'):
 for actor in (101,102,103):
  test('mapped lead provider '+app+' actor '+str(actor),m['check']({},dict(source,app=app,actor=actor),'review-protocol','claude'),True)
 for window in ('terra','batch'):
  test('mapped worker '+app+window,m['check']({},dict(source,app=app,window=window),'review-protocol','claude'),True)
for session in ('config','cvmapp','vetmed-absence-expansion'):
 test('worker stays with project '+session,m['check']({},dict(source,session=session,window='terra'),'review-protocol','claude'),False)
 test('worker local '+session,m['check']({},dict(source,session=session,window='terra'),session,'claude'),True)
for target in [('other','claude'),('review-protocol','unassigned')]:
 test('unrelated target '+str(target),m['check']({},source,*target),False)
state['live']=lambda env,src:False
test('stale mapped lead',m['check']({},source,'review-protocol','claude'),False)
state['live']=lambda env,src:True
f=m['record_caller'];exe=pathlib.Path(sys.executable).resolve();state['process_executable']=lambda pid:exe
state['ancestors']=lambda pid:[(201,202,'/fixture/truncated',''),(202,1,'/fixture/claude','claude')]
with tempfile.TemporaryDirectory() as d:
 record=pathlib.Path(d)/'record.json';record.write_text('{}');queue=TOOLS/'cc-msg-queue';bound={'actor':202}
 def argv(values):state['LABEL']['ps']=lambda *args:shlex.join([str(exe),*map(str,values)])
 for flags in [[],['-u'],['-B'],['-I'],['-E'],['-s'],['-S'],['-O'],['-OO'],['--'],['-u','-B','--']]:
  argv([*flags,queue,'--worker',record]);test('canonical Python flags '+str(flags),f(201,record,bound),True)
 for flags in [['-c'],['-m'],['-X','dev'],['--garbage']]:
  argv([*flags,queue,'--worker',record]);test('non-script invocation '+str(flags),f(201,record,bound),False)
 argv([queue,'ordinary message contains --worker /wrong']);test('literal worker flag payload accepted',f(201,record,bound),True)
 argv([queue,'ordinary','--prove',queue]);test('later literal prove flag accepted',f(201,record,bound),True)
 argv([queue,'--worker',queue]);test('other record refused',f(201,record,bound),False)
 argv([queue,'--worker',record]);state['ancestors']=lambda pid:[(201,203,'/fixture/truncated',''),(203,202,'/real/codex','codex'),(202,1,'/real/claude','claude')]
 test('nested native worker cannot borrow CC actor',f(201,record,bound),False)
 state['ancestors']=lambda pid:[(201,202,'/fixture/truncated',''),(202,1,'/real/claude','claude')]
 state['process_executable']=lambda pid:exe if pid==204 else pathlib.Path('/bin/bash')
 state['ancestors']=lambda pid:[(201,204,'/fixture/truncated',''),(204,202,'/fixture/scheduler',''),(202,1,'/real/codex','codex')]
 bound={'actor':303}
 argv([queue,'--schedule',record.parent,'3']);test('shared scheduler accepts other bound source',f(201,record,bound),True)
 argv([queue,'--schedule',TOOLS,'3']);test('scheduler other target folder refused',f(201,record,bound),False)
 argv([queue,'--schedule',record.parent,'2']);test('scheduler invalid owner descriptor refused',f(201,record,bound),False)
 argv([queue,'--schedule',record.parent,'3','extra']);test('scheduler extra args refused',f(201,record,bound),False)
 argv([queue,'--worker',record]);test('ordinary worker cannot borrow another source',f(201,record,bound),False)
 argv([queue,'--schedule',record.parent,'3']);state['ancestors']=lambda pid:[(201,203,'/fixture/truncated',''),(203,204,'/real/agy','agy'),(204,202,'/fixture/scheduler',''),(202,1,'/real/codex','codex')]
 test('native actor below scheduler cannot borrow source',f(201,record,bound),False)
 state['ancestors']=lambda pid:[(201,202,'/fixture/truncated',''),(202,1,'/real/claude','claude')]
 bound={'actor':202}
 state['process_executable']=lambda pid:pathlib.Path('/bin/bash')
 test('bash claiming queue script refused',f(201,record,bound),False)
print(json.dumps({'passed':len(cases),'cases':cases},indent=2))
