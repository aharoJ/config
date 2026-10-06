#!/usr/bin/env python3
import json
import pathlib
import runpy
import tempfile

module = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'tools' / 'relay-route-guard'))
check = module['check']
state = check.__globals__
source = {'session': 'cvmapp', 'window': 'claude', 'app': 'claude'}
rule = {'source': ['cvmapp', 'claude'], 'target': ['config', 'claude']}
state['policy'] = lambda: [rule]
state['live'] = lambda env, value: True
state['signed'] = lambda value: True
cases = []

def test(name, actual, expected):
    assert actual == expected, name
    cases.append(name)


test('same session worker', check({}, dict(source, app='codex'), 'cvmapp', 'claude'), True)
test('signed allowlisted CC', check({}, source, 'config', 'claude'), True)
for app in ('codex', 'agy', 'gemini', 'relay'):
    test('cross refused '+app, check({'CC_MSG_ALLOW_CROSS_SESSION': '1'}, dict(source, app=app), 'config', 'claude'), False)
test('non allowlisted source', check({}, dict(source, session='unknown'), 'config', 'claude'), False)
test('wrong destination window', check({}, source, 'config', 'codex'), False)
test('wrong destination session', check({}, source, 'other', 'claude'), False)
state['signed'] = lambda value: False
test('unsigned claimed CC', check({}, source, 'config', 'claude'), False)
state['live'] = lambda env, value: False
test('dead queued source same session', check({}, source, 'cvmapp', 'claude'), False)
test('dead queued source cross', check({}, source, 'config', 'claude'), False)
bound = {'version': 1, 'socket': {'inode': 7}, 'pane': '%4', 'session': 'cvmapp', 'window': 'claude', 'root': 100, 'root_identity': 'root-start', 'actor': 101, 'actor_identity': 'actor-start', 'app': 'claude'}
state['socket'] = lambda env: {'inode': 7}
state['panes'] = lambda env: [['%4', 'cvmapp', 'claude', '', '100', '0']]
state['identity'] = lambda pid: 'root-start' if pid == 100 else 'actor-start'
state['ancestors'] = lambda pid: [(101, 100, '/real/claude', 'claude'), (100, 1, '/bin/fish', '')]
state['foreground'] = lambda actor, root: True
test('live bound source', module['live']({}, bound), True)
for key, value in [('socket', {'inode': 8}), ('pane', '%5'), ('session', 'other'), ('window', 'other'), ('root_identity', 'reused'), ('actor_identity', 'reused'), ('app', 'codex')]:
    test('stale binding '+key, module['live']({}, dict(bound, **{key: value})), False)
state['foreground'] = lambda actor, root: False
test('source no foreground subtree', module['live']({}, bound), False)
original = module['policy'].__globals__
with tempfile.TemporaryDirectory() as directory:
    record = pathlib.Path(directory) / 'record.json'
    record.write_text('{}')
    queue = pathlib.Path(__file__).resolve().parents[1] / 'tools' / 'cc-msg-queue'
    state['ancestors'] = lambda pid: [(201, 1, '/usr/bin/python3', '')]
    state['LABEL']['ps'] = lambda *args: f'python3 {queue} --worker {record}'
    test('canonical queue exact record', module['record_caller'](201, record, {'actor': 101}), True)
    clear = queue.with_name('relay-clear-draft')
    plan = record.with_suffix('.plan')
    plan.write_text(json.dumps({'record': str(record)}))
    state['LABEL']['ps'] = lambda *args: f'python3 {clear} --prove {plan}'
    test('canonical clear exact plan record', module['record_caller'](201, record, {'actor': 101}), True)
    plan.write_text(json.dumps({'record': str(queue)}))
    test('clear plan wrong record refused', module['record_caller'](201, record, {'actor': 101}), False)
    state['LABEL']['ps'] = lambda *args: f'python3 {queue} --worker {queue}'
    test('queue wrong record refused', module['record_caller'](201, record, {'actor': 101}), False)
    state['LABEL']['ps'] = lambda *args: f'python3 -c {queue}'
    test('python code path claim refused', module['record_caller'](201, record, {'actor': 101}), False)
    state['LABEL']['ps'] = lambda *args: f'python3 {queue} --worker {record}'
    state['ancestors'] = lambda pid: [(201, 202, '/usr/bin/python3', ''), (202, 1, '/bin/codex', 'codex')]
    test('worker cannot borrow CC record', module['record_caller'](201, record, {'actor': 101}), False)
    state['ancestors'] = lambda pid: [(201, 1, '/bin/bash', '')]
    test('env only record refused', module['record_caller'](201, record, {'actor': 101}), False)
    path = pathlib.Path(directory) / 'policy.json'
    path.write_text(json.dumps({'version': 1, 'allow': [rule]}))
    path.chmod(0o600)
    original['POLICY'] = path
    test('operator policy valid', module['policy'](), [rule])
    path.chmod(0o666)
    try:
        module['policy']()
        raise AssertionError('writable policy accepted')
    except ValueError:
        cases.append('writable policy refused')
print(json.dumps({'passed': len(cases), 'cases': cases}, indent=2))
