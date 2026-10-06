#!/usr/bin/env python3
# path: ~/.config/tmux/tests/relay-mapped-route-regression.py
# description: Verify both directions and all seats of the exact operator mapping.
# date: 2026-10-06
import pathlib
import runpy

module = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'tools/relay-route-guard'))
check = module['check']
state = check.__globals__
state['live'] = lambda env, source: True
state['signed'] = lambda source: True
state['destination_cc'] = lambda env, session, window: True
state['destination_client'] = lambda env, session, window: True
source = dict(session='rp-schema', window='codex', app='codex')
cases = 0
for app in ('claude', 'codex', 'agy', 'gemini'):
    for window in ('codex', 'terra', 'batch', 'claude'):
        assert check({}, dict(source, app=app, window=window), 'review-protocol', 'claude')
        cases += 1
for window in ('codex', 'terra', 'batch', 'claude'):
    assert check({}, dict(source, session='review-protocol', window='claude', app='claude'), 'rp-schema', window)
    cases += 1
for source_seat in [('review-protocol', 'codex'), ('config', 'codex'), ('config', 'claude')]:
    assert not check({}, dict(source, session=source_seat[0], window=source_seat[1], app='claude'), 'rp-schema', 'terra')
    cases += 1
state['signed'] = lambda source: False
assert not check({}, dict(source, session='review-protocol', window='claude', app='claude'), 'rp-schema', 'codex')
cases += 1
state['signed'] = lambda source: True
state['destination_client'] = lambda env, session, window: False
assert not check({}, dict(source, session='review-protocol', window='claude', app='claude'), 'rp-schema', 'terra')
cases += 1
assert not check({}, dict(source, session='unmapped'), 'review-protocol', 'claude')
cases += 1
print(f'PASS: {cases} exact mapped relationship checks; adjacent sources and unsupported targets denied')
