#!/usr/bin/env python3
import json
import pathlib
import runpy
import tempfile

module = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'tools' / 'relay-route-guard'))
check = module['check']
state = check.__globals__
cases = []

def test(name, actual, expected):
    assert actual == expected, name
    cases.append(name)

source = {'session': 'cvmapp', 'window': 'whale-3', 'app': 'codex', 'socket': {'inode': 7}, 'actor': 101}
state['live'] = lambda env, value: not value.get('stale', False)
state['AGENT']['prove'] = lambda pid: {'app':'codex', 'entrypoint':[None]}
state['LABEL']['process_argv'] = lambda pid: ['codex','--no-daemon']
state['panes'] = lambda env: [['%9', 'other-project', 'blue-27', '', '200', '0'], ['%8', 'cvmapp', 'red', '', '300', '0']]
state['pane_source'] = lambda env, row: dict(source, session=row[1], window=row[2])
for app in ('claude', 'codex', 'agy', 'gemini', 'relay'):
    for target in [('other-project', 'blue-27'), ('cvmapp', 'red')]:
        state['AGENT']['prove'] = lambda pid, app=app: {'app':app, 'entrypoint':[None]} if app != 'relay' else None
        test('symmetric explicit peer '+app+str(target), check({}, dict(source, app=app), *target), app != 'relay')
for app in ('claude', 'codex', 'agy', 'gemini', 'relay'):
    state['pane_source'] = lambda env, row, app=app: dict(source, app=app, actor=202)
    state['AGENT']['prove'] = lambda pid, app=app: {'app':'codex' if pid==101 else app, 'entrypoint':[None]} if pid==101 or app != 'relay' else None
    test('target provider '+app, check({}, source, 'other-project', 'blue-27'), app != 'relay')
state['pane_source'] = lambda env, row: dict(source)
state['AGENT']['prove'] = lambda pid: {'app':'codex','entrypoint':[None]}
for target in [('missing', 'blue'), ('other-project', 'missing'), ('bad session', 'blue-27'), ('other-project', '1:blue')]:
    test('missing or invalid address '+str(target), check({}, source, *target), False)
test('dead source', check({}, dict(source, stale=True), 'other-project', 'blue-27'), False)
state['pane_source'] = lambda env, row: dict(source, stale=True)
test('dead target', check({}, source, 'other-project', 'blue-27'), False)
state['pane_source'] = lambda env, row: dict(source, socket={'inode':8})
test('other socket target', check({}, source, 'other-project', 'blue-27'), False)
state['pane_source'] = lambda env, row: dict(source)
test('live operator shell to verified target', check({'RELAY_OPERATOR':'1'}, dict(source, app='relay'), 'other-project', 'blue-27'), True)
state['panes'] = lambda env: [['%9', 'other-project', 'blue-27', '', '200', '0']]*2
test('ambiguous target', check({}, source, 'other-project', 'blue-27'), False)
state['panes'] = lambda env: [['%9', 'other-project', 'blue-27', '', '200', '0']]
state['live'] = lambda env, value: value.get('socket') != {'inode':7} or value is source
test('target generation changed before route return', check({}, source, 'other-project', 'blue-27'), False)
bound = {'version': 1, 'socket': {'inode': 7}, 'pane': '%4', 'session': 'cvmapp', 'window': 'claude', 'root': 100, 'root_identity': 'root-start', 'actor': 101, 'actor_identity': 'actor-start', 'app': 'claude'}
state['socket'] = lambda env: {'inode': 7}
state['panes'] = lambda env: [['%4', 'cvmapp', 'claude', '', '100', '0']]
state['identity'] = lambda pid: 'root-start' if pid == 100 else 'actor-start'
state['ancestors'] = lambda pid: [(101, 100, '/real/claude', 'claude'), (100, 1, '/bin/fish', '')]
state['foreground'] = lambda actor, root: True
state['AGENT']['prove'] = lambda pid: {'app':'claude'}
test('live bound source', module['live']({}, bound), True)
for key, value in [('socket', {'inode': 8}), ('pane', '%5'), ('session', 'other'), ('window', 'other'), ('root_identity', 'reused'), ('actor_identity', 'reused'), ('app', 'codex')]:
    test('stale binding '+key, module['live']({}, dict(bound, **{key: value})), False)
state['foreground'] = lambda actor, root: False
test('source no foreground subtree', module['live']({}, bound), False)
with tempfile.TemporaryDirectory() as directory:
    record = pathlib.Path(directory) / 'record.json'
    record.write_text('{}')
    queue = pathlib.Path(__file__).resolve().parents[1] / 'tools' / 'cc-msg-queue'
    state['ancestors'] = lambda pid: [(201, 1, '/usr/bin/python3', '')]
    state['process_executable'] = lambda pid: pathlib.Path('/usr/bin/python3').resolve()
    state['LABEL']['process_argv'] = lambda pid: ['python3', str(queue), '--worker', str(record)]
    test('canonical queue exact record', module['record_caller'](201, record, {'actor': 101}), True)
    clear = queue.with_name('relay-clear-draft')
    plan = record.with_suffix('.plan')
    plan.write_text(json.dumps({'record': str(record)}))
    state['LABEL']['process_argv'] = lambda pid: ['python3', str(clear), '--prove', str(plan)]
    test('canonical clear exact plan record', module['record_caller'](201, record, {'actor': 101}), True)
    plan.write_text(json.dumps({'record': str(queue)}))
    test('clear plan wrong record refused', module['record_caller'](201, record, {'actor': 101}), False)
    state['LABEL']['process_argv'] = lambda pid: ['python3', str(queue), '--worker', str(queue)]
    test('queue wrong record refused', module['record_caller'](201, record, {'actor': 101}), False)
    state['LABEL']['process_argv'] = lambda pid: ['python3', '-c', str(queue)]
    test('python code path claim refused', module['record_caller'](201, record, {'actor': 101}), False)
    state['LABEL']['process_argv'] = lambda pid: ['python3', str(queue), '--worker', str(record)]
    state['ancestors'] = lambda pid: [(201, 202, '/usr/bin/python3', ''), (202, 1, '/bin/codex', 'codex')]
    test('worker cannot borrow CC record', module['record_caller'](201, record, {'actor': 101}), False)
    state['ancestors'] = lambda pid: [(201, 1, '/bin/bash', '')]
    state['process_executable'] = lambda pid: pathlib.Path('/bin/bash')
    test('env only record refused', module['record_caller'](201, record, {'actor': 101}), False)
print(json.dumps({'passed': len(cases), 'cases': cases}, indent=2))
