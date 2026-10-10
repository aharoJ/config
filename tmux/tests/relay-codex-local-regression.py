import runpy
import subprocess
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
guard = runpy.run_path(str(TOOLS / 'relay-route-guard'))
g = guard['bind'].__globals__
source = dict(actor=100, app='codex')
g['LABEL']['processes'] = lambda: {100:(1,'/canonical/codex'), 101:(100,'/canonical/codex')}
g['ancestors'] = lambda pid, table=None: [(pid,100,'/canonical/codex','codex'),(100,1,'/canonical/codex','codex')] if pid==101 else [(100,1,'/canonical/codex','codex')]
g['AGENT']['prove'] = lambda pid: dict(app='codex',entrypoint=[None])
g['LABEL']['process_argv'] = lambda pid: ['codex','--no-daemon'] if pid==100 else ['codex','app-server']
assert guard['local_codex'](source)
for argv in (['codex'], ['codex','--','--no-daemon'], ['codex','--no-daemon','--remote','unix:///tmp/other'], ['codex','--no-daemon','--remote=unix:///tmp/other'], ['codex','--no-daemon','app-server']):
    g['LABEL']['process_argv'] = lambda pid, value=argv: value
    assert not guard['local_codex'](source), argv
g['LABEL']['process_argv'] = lambda pid: ['codex','--no-daemon']
assert not guard['local_codex'](source)
g['AGENT']['prove'] = lambda pid: None
assert not guard['local_codex'](source)
mode = runpy.run_path(str(TOOLS / 'relay-route-guard'))
m = mode['bind'].__globals__
m['AGENT']['prove'] = lambda pid: dict(app='codex',entrypoint=[None])
m['ancestors'] = lambda pid: [(100,1,'/canonical/codex','codex')]
m['daemon_source'] = lambda env, chain: None
m['panes'] = lambda env: [['%1','swarm','blue','','100','0'],['%2','swarm','red','','200','0']]
m['LABEL']['origin'] = lambda pid, rows: (('%1','swarm','blue',100,'codex'),[(100,1,'/canonical/codex','codex')])
m['identity'] = lambda pid: 'generation'
m['socket'] = lambda env: dict(inode=7)
m['live'] = lambda env, source: True
m['pane_source'] = lambda env, row: dict(actor=200,app='codex',socket=dict(inode=7))
negative = [[], ['--remote','unix:///remote'], ['--no-daemon','--remote=unix:///remote'], ['--no-daemon','app-server','daemon'], ['--config','model=fixture','--no-daemon','app-server','daemon'], ['--','--no-daemon'], ['--no-daemon','--no-daemon'], ['--no-daemon','exec','prompt'], ['--no-daemon','--unknown-future-mode'], ['--no-daemon','future-subcommand']]
for args in negative:
    m['LABEL']['process_argv'] = lambda pid, args=args: ['codex',*args] if pid==100 else ['codex','--no-daemon']
    assert not mode['local_source'](dict(actor=100)), args
    assert not mode['check']({},dict(actor=100,app='codex',socket=dict(inode=7)), 'swarm','red'), args
    try:
        mode['bind']({},100)
    except ValueError as error:
        assert 'exact local native launch' in str(error), error
    else:
        raise AssertionError(('nonlocal actor accepted',args))
for args in (['--no-daemon'], ['--model','app-server','--no-daemon','resume','thread'], ['--no-daemon','fork','thread'], ['--no-daemon','--','--remote'], ['--local-provider','fixture','--no-daemon'], ['--no-daemon','--','future-subcommand'], ['--no-daemon','--image','one.png','--image','two.png'], ['--no-daemon','--image','one.png','two.png']):
    m['LABEL']['process_argv'] = lambda pid, args=args: ['codex',*args]
    assert mode['local_source'](dict(actor=100)), args
    assert mode['bind']({},100)['actor']==100
    assert mode['check']({},dict(actor=100,app='codex',socket=dict(inode=7)), 'swarm','red'), args
m['AGENT']['prove'] = lambda pid: dict(app='codex',entrypoint=['/canonical/codex.js'])
assert not mode['local_source'](dict(actor=100))
g['daemon_source'] = lambda env, chain: None
g['ancestors'] = lambda pid, table=None: [(200,1,'unknown-execution-host','')]
g['LABEL']['origin'] = lambda pid, rows: None
g['panes'] = lambda env: [['%1','swarm','blue','','100','0']]
try:
    guard['bind'](dict(TMUX_PANE='%1',CODEX_THREAD_ID='00000000-0000-4000-8000-000000000001'),200)
except ValueError as error:
    assert str(error)=='canonical source ancestry unavailable', error
else:
    raise AssertionError('detached unknown host borrowed another pane')
wrapper = TOOLS.parents[1] / 'fish/internal/codex/codex.fish'
script = 'source '+str(wrapper)+"; function _agent_limit; printf '%s\n' $argv; end; codex $argv"
for argv in (['--image','one.png','two.png'], ['--model-gpt-5-5'], ['--model-gpt-5-3-codex'], ['--image','one.png','--image','two.png'], [], ['--model-lead'], ['--model-audit'], ['--no-daemon'], ['--model-lead','--no-daemon'], ['--model-audit','--no-daemon','--no-daemon'], ['-m','future-model','resume','00000000-0000-4000-8000-000000000001'], ['--config','exec'], ['--model','app-server'], ['fork','thread']):
    result = subprocess.run(['fish','--no-config','-c',script,'--',*argv],capture_output=True,text=True,check=True)
    args = result.stdout.splitlines()
    assert args[:2] == ['codex','--no-daemon'], args
    assert args.count('--no-daemon') == 1, args
    assert '--dangerously-bypass-approvals-and-sandbox' in args, args
    if argv[:1] == ['-m']:
        assert args[-len(argv):] == argv, args
print('PASS local native recognition, remote/unknown/ambiguous refusals and detached borrowed-hint refusal')

for argv in (['exec','prompt'], ['--config','model=fixture','app-server','--help'], ['remote-control','--help'], ['--model-lead','app-server','--help'], ['--model','exec','remote-control'], ['future-subcommand'], ['--remote','unix:///remote'], ['--remote=unix:///remote'], ['--remote-auth-token-env','FIXTURE_TOKEN'], ['--remote-auth-token-env=FIXTURE_TOKEN']):
    result=subprocess.run(['fish','--no-config','-c',script,'--',*argv],capture_output=True,text=True,check=True)
    args=result.stdout.splitlines()
    assert '--no-daemon' not in args, (argv,args)
for argv in (['--no-daemon','--','--no-daemon'], ['--','--no-daemon'], ['--no-daemon','app-server','--help'], ['--','future-subcommand']):
    result=subprocess.run(['fish','--no-config','-c',script,'--',*argv],capture_output=True,text=True,check=True)
    args=result.stdout.splitlines()
    assert args[:2]==['codex','--no-daemon'],args
    assert args.count('--no-daemon')==(2 if '--' in argv and argv[-1]=='--no-daemon' else 1),args
print('PASS exact-actor bind/queued checks, option parsing, explicit flag deduplication and non-TUI wrapper compatibility')

for argv in (['--model-gpt-5-5','-m','raw'], ['--model-gpt-5-5','--model-audit'], ['--model-gpt-5-3-codex','--model-gpt-5-5']):
    result=subprocess.run(['fish','--no-config','-c',script,'--',*argv],capture_output=True,text=True)
    assert result.returncode==2 and not result.stdout, (argv,result)
print('PASS combined presets and repeated-image form; variadic images retain local authority')
