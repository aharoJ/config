#!/usr/bin/env python3
import json
import pathlib
import runpy
import tempfile

module = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'tools/relay-route-guard'))
g = module['bind'].__globals__
first = '00000000-0000-4000-8000-000000000001'
second = '00000000-0000-4000-8000-000000000002'
source = dict(version=2, app='codex', pane='%1', session='config', window='codex', root=100, root_identity='root', actor=101, actor_identity='actor', socket=dict(device=1, inode=2))
chain = [(200, 1, '/bin/codex', '')]
g['LABEL']['process_argv'] = lambda pid: ['codex', 'app-server', '--managed-daemon']
g['socket'] = lambda env: source['socket']
g['panes'] = lambda env: [[source['pane'], source['session'], source['window'], '', '100', '0']]
g['identity'] = lambda pid: 'root' if pid == 100 else 'actor'
g['ancestors'] = lambda pid: [(101, 100, '/bin/codex', 'codex'), (100, 1, '/bin/fish', '')]
g['foreground'] = lambda *args: True
with tempfile.TemporaryDirectory() as directory:
    path = pathlib.Path(directory) / 'bindings.json'
    g['SOURCE_BINDINGS'] = path
    env = dict(CODEX_THREAD_ID=first, CODEX_SESSION_ID=first, TMUX_PANE='%1')
    def refused(environment):
        try:
            module['daemon_source'](environment, chain)
        except ValueError:
            return
        raise AssertionError('unproven daemon accepted')
    refused(env)
    data = dict(version=1, bindings={first:source}, active={'1:2:%1':first})
    path.write_text(json.dumps(data)); path.chmod(0o600)
    assert module['daemon_source'](env, chain) == dict(source, thread_id=first)
    refused(dict(env, CODEX_SESSION_ID=second))
    refused(dict(env, CODEX_THREAD_ID=second, CODEX_SESSION_ID=second))
    data['active']['1:2:%1'] = second; path.write_text(json.dumps(data))
    refused(env)
    data['active']['1:2:%1'] = first; path.write_text(json.dumps(data))
    g['identity'] = lambda pid: 'reused'
    refused(env)
    g['identity'] = lambda pid: 'root' if pid == 100 else 'actor'
    path.chmod(0o666); refused(env)
    path.chmod(0o600)
    assert module['daemon_source'](env, [(201,1,'/bin/fish','')]) is None
print('PASS: daemon refuses inherited hints, wrong/missing/retired threads, reused actors and unsafe bindings; native callers do not borrow leases')
