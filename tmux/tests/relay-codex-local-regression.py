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
for argv in ([], ['--model-lead'], ['--model-audit'], ['-m','future-model','resume','00000000-0000-4000-8000-000000000001']):
    result = subprocess.run(['fish','--no-config','-c',script,'--',*argv],capture_output=True,text=True,check=True)
    args = result.stdout.splitlines()
    assert args[:2] == ['codex','--no-daemon'], args
    assert args.count('--no-daemon') == 1, args
    assert '--dangerously-bypass-approvals-and-sandbox' in args, args
    if argv[:1] == ['-m']:
        assert args[-len(argv):] == argv, args
print('PASS local native recognition, remote/unknown/ambiguous refusals and detached borrowed-hint refusal')
