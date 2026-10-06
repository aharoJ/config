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

source = {'session': 'cvmapp', 'window': 'codex', 'app': 'codex'}
state['live'] = lambda env, value: True
for app in ('claude', 'codex', 'agy', 'gemini', 'relay'):
    for window in ('claude', 'codex'):
        seat = dict(source, app=app, window=window)
        test('lead provider parity '+app+window, check({}, seat, 'config', 'codex'), app != 'relay')
        test('lead to lead '+app+window, check({}, seat, 'review-protocol', 'claude'), app != 'relay')
    worker = dict(source, app=app, window='terra')
    test('worker local '+app, check({}, worker, 'cvmapp', 'codex'), True)
    test('worker cannot skip project orcha '+app, check({}, worker, 'review-protocol', 'claude'), False)
    test('worker unrelated project '+app, check({}, worker, 'config', 'claude'), False)
for app in ('claude', 'codex', 'agy', 'gemini'):
    schema = dict(source, session='rp-schema', window='codex', app=app)
    test('rp-schema upward '+app, check({}, schema, 'review-protocol', 'claude'), True)
    hub = dict(source, session='review-protocol', window='claude', app=app)
    test('rp-schema return '+app, check({}, hub, 'rp-schema', 'codex'), True)
vetmed = dict(source, session='vetmed-absence-expansion', window='terra')
test('declared vetmed terra reports to local lead', check({}, vetmed, 'vetmed-absence-expansion', 'claude'), True)
test('declared vetmed terra cannot skip local lead', check({}, vetmed, 'review-protocol', 'claude'), False)
test('declared vetmed terra cannot reach config', check({}, vetmed, 'config', 'claude'), False)
test('unknown session denied', check({}, dict(source, session='unknown'), 'config', 'claude'), False)
test('unknown destination denied', check({}, source, 'other', 'codex'), False)
test('unknown destination seat denied', check({}, source, 'config', 'unassigned'), False)
test('vendor name grants no worker privilege', check({}, dict(source, window='worker', app='claude'), 'config', 'claude'), False)
state['live'] = lambda env, value: False
test('dead source local', check({}, source, 'cvmapp', 'claude'), False)
test('dead source cross', check({}, source, 'config', 'codex'), False)
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
    path = pathlib.Path(directory) / 'policy.json'
    path.write_text(json.dumps({'version': 2, 'seats': {'cvmapp': {'codex': 'lead'}}}))
    path.chmod(0o600)
    original['POLICY'] = path
    test('operator policy valid', module['policy'](), {'cvmapp': {'codex': 'lead'}})
    path.chmod(0o666)
    try:
        module['policy']()
        raise AssertionError('writable policy accepted')
    except ValueError:
        cases.append('writable policy refused')
print(json.dumps({'passed': len(cases), 'cases': cases}, indent=2))
