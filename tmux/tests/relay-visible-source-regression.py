#!/usr/bin/env python3
import json
import pathlib
import runpy
import sqlite3
import tempfile
from unittest.mock import patch

TOOLS = pathlib.Path(__file__).resolve().parents[1] / 'tools'
module = runpy.run_path(str(TOOLS / 'relay-visible-source'))
g = module['discover'].__globals__


def refuses(call):
    try:
        call()
    except (ValueError, json.JSONDecodeError):
        return
    raise AssertionError('unsafe evidence accepted')


text = 'Unique submitted turn αβ with wrapped words'
screen = '› Unique submitted turn αβ\n  with wrapped words\n\n• Working\n\n› Ask Codex to do anything\n'
assert module['visible_turn'](screen) == text
for bad in ['› draft\n', '› draft\n› empty\n', screen.replace('Ask Codex to do anything', 'owned draft'), screen.replace('• Working', 'cropped'), screen.replace('Unique', '[Pasted Content 42]'), screen.replace('Unique', '…')]:
    refuses(lambda: module['visible_turn'](bad))

source = dict(version=2, app='codex', pane='%1', session='config', window='codex')
other = dict(source, pane='%2', window='terra')
calls = []
screens = {'=config:=codex': screen, '=config:=terra': screen.replace('Unique', 'Other')}
metadata = {'=config:=codex': '%1|0|0', '=config:=terra': '%2|0|0'}


def run(env, *args):
    calls.append(args)
    assert args[0] == 'tmux' and args[1] in ('capture-pane', 'display-message')
    target = args[args.index('-t') + 1]
    return metadata[target] if args[1] == 'display-message' else screens[target]


def discover(turns, seats=(source, other)):
    with patch.dict(g, stored_turns=lambda requested: turns):
        return module['discover']({}, 'thread', run, lambda env: seats, lambda env, row: row, lambda env, bound: True)


assert discover({'thread': text}) == source
refuses(lambda: discover({}))
refuses(lambda: discover({'thread': text, 'copied': text}))
screens['=config:=terra'] = screen
refuses(lambda: discover({'thread': text}))
screens['=config:=terra'] = screen.replace('Unique', 'Other')
for mode in ('%1|1|0', '%1|0|1', '%99|0|0'):
    metadata['=config:=codex'] = mode
    refuses(lambda: discover({'thread': text}))
metadata['=config:=codex'] = '%1|0|0'
refuses(lambda: discover({'thread': 'fresh after reset'}))
screens['=config:=codex'] = screen.replace('Unique', 'Reset')
assert discover({'new-thread': text, 'thread': text.replace('Unique', 'Reset')}) == source

with tempfile.TemporaryDirectory() as directory:
    root = pathlib.Path(directory)
    state, history, rollout = root / 'state.sqlite', root / 'history.sqlite', root / 'rollout.jsonl'
    with sqlite3.connect(state) as db:
        db.execute('CREATE TABLE threads (id TEXT,rollout_path TEXT,history_mode TEXT)')
        db.executemany('INSERT INTO threads VALUES (?,?,?)', [('thread', str(rollout), 'paginated'), ('legacy', str(rollout), 'legacy')])
    with sqlite3.connect(history) as db:
        db.execute('CREATE TABLE thread_items (thread_id TEXT,item_json TEXT,item_type TEXT,rollout_ordinal INTEGER)')
        db.execute('INSERT INTO thread_items VALUES (?,?,?,?)', ('thread', json.dumps(dict(type='userMessage',content=[dict(type='text',text=text)])), 'userMessage', 1))
    rollout.write_text(json.dumps(dict(type='event_msg',payload=dict(type='user_message',message='legacy distinct'))) + '\n')
    for path in (state, history, rollout):
        path.chmod(0o600)
    with patch.dict(g, STATE=state, HISTORY=history, CACHE=root / 'cache.json'):
        assert module['stored_turns']('thread') == {'thread': text, 'legacy': 'legacy distinct'}
        rollout.write_text(rollout.read_text() + '{"partial":')
        refuses(lambda: module['stored_turns']('thread'))

guard = runpy.run_path(str(TOOLS / 'relay-route-guard'))
gg = guard['automatic_source'].__globals__
registered = dict(source, binding_epoch='epoch')
with patch.dict(gg, source_bindings=lambda: {'bindings': {}, 'proofs': {}}, visible_source=lambda env, thread: source,
                register_source=lambda *args, **kwargs: registered, live=lambda *args: True):
    assert guard['automatic_source']({}, 'thread') == dict(registered, thread_id='thread')
full = dict(registered, root=100, root_identity='root', actor=101, actor_identity='actor', socket=dict(device=1,inode=2))
data = dict(bindings={'thread': full}, active={'1:2:%1': 'thread'}, proofs={'thread': dict(kind='visible-turn',since=1)})
with tempfile.TemporaryDirectory() as directory:
    binding_path = pathlib.Path(directory) / 'bindings.json'
    binding_path.write_text('{}')
    current = {key: value for key, value in full.items() if key != 'binding_epoch'}
    with patch.dict(gg, SOURCE_BINDINGS=binding_path, source_bindings=lambda: data, socket=lambda env: full['socket'],
                    thread_retired=lambda *args: False, visible_source=lambda *args: current,
                    panes=lambda env: [['%1','config','codex','','100','0']],
                    identity=lambda pid: 'root' if pid == 100 else 'actor',
                    ancestors=lambda pid: [(101,100,'codex','codex'),(100,1,'shell','')], foreground=lambda *args: True):
        assert guard['live']({}, dict(full,thread_id='thread'))
        with patch.dict(gg, visible_source=lambda *args: dict(current, actor=102)):
            assert not guard['live']({}, dict(full,thread_id='thread'))
        with patch.dict(gg, thread_retired=lambda *args: True):
            assert not guard['live']({}, dict(full,thread_id='thread'))
        data['active']['1:2:%1'] = 'replacement'
        assert not guard['live']({}, dict(full,thread_id='thread'))
assert all(call[1] in ('capture-pane', 'display-message') for call in calls)
print('PASS passive uniqueness, identical/copy/reset seats, copy/alternate mode, cropped turns, SQLite/JSONL and partial writes; no input commands')
