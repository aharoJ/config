import json,pathlib,runpy,shlex,sys,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1];TOOLS=ROOT/'tools';m=runpy.run_path(str(TOOLS/'relay-route-guard'));state=m['check'].__globals__;cases=[]
def test(name,actual,expected):
 assert actual==expected,(name,actual,expected)
 cases.append(name)
state['live']=lambda env,src:True
state['destination_cc']=lambda env,s,w:True
state['process_executable']=lambda pid:pathlib.Path('/lab/codex' if pid==101 else '/lab/node')
state['ancestors']=lambda pid:[(pid,100,'/lab/codex' if pid==101 else '/lab/node','codex')]
source={'app':'codex','actor':101,'session':'rp-schema','window':'codex'}
test('native exact live actor authorized',m['check']({},source,'review-protocol','claude'),True)
for key,values in [('session',['config','review-protocol','terra','rp-schema-extra']),('window',['terra','claude','batch']),('app',['agy','gemini','relay'])]:
 for value in values:test('source '+key+' '+value,m['check']({},dict(source,**{key:value}),'review-protocol','claude'),key=='session' and value=='review-protocol')
for session,window in [('config','claude'),('review-protocol','codex'),('other','claude'),('review-protocol-extra','claude')]:
 test('target '+session+':'+window,m['check']({'CC_MSG_ALLOW_CROSS_SESSION':'1'},source,session,window),False)
for actor in [102,103]:test('node or daemon actor '+str(actor),m['check']({},dict(source,actor=actor),'review-protocol','claude'),False)
state['destination_cc']=lambda env,s,w:False
test('destination not signed CC',m['check']({},source,'review-protocol','claude'),False)
state['destination_cc']=lambda env,s,w:True
actualpolicy=state['policy']();test('exactly one worker rule',sum(r.get('app')=='native-codex' for r in actualpolicy),1);state['policy']=lambda:[r for r in actualpolicy if r.get('app')!='native-codex']
test('missing exact operator rule',m['check']({},source,'review-protocol','claude'),False)
state['policy']=lambda:actualpolicy
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
 state['process_executable']=lambda pid:pathlib.Path('/bin/bash')
 test('bash claiming queue script refused',f(201,record,bound),False)
print(json.dumps({'passed':len(cases),'cases':cases},indent=2))
