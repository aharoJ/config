#!/usr/bin/env python3
"""The same assertions must fail on 552d406 and pass on its repair."""
import argparse
import json
import pathlib
import runpy
import tempfile
import time
from unittest.mock import patch

parser = argparse.ArgumentParser()
parser.add_argument('--module',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1] / 'tools/relay-visible-source')
parser.add_argument('--output',type=pathlib.Path)
parser.add_argument('--guard',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1] / 'tools/relay-route-guard')
args = parser.parse_args()
module = runpy.run_path(str(args.module))
result = {}
with tempfile.TemporaryDirectory() as directory:
    rollout = pathlib.Path(directory) / 'rollout.jsonl'
    rollout.write_text(json.dumps(dict(type='event_msg',payload=dict(type='user_message',message='uncommitted'))))
    rollout.chmod(0o600)
    try:
        module['rollout_turn'](rollout,time.monotonic()+1)
    except ValueError:
        result['unterminated_jsonl_refused'] = True
    else:
        result['unterminated_jsonl_refused'] = False
own = '› exact pane turn\n\n• Finished\n\n› Ask Codex to do anything\n'
foreign = own.replace('exact pane turn','foreign active pane turn')
commands = []
def run(env,*args):
    commands.append(args)
    target = args[args.index('-t')+1]
    if args[1] == 'display-message':
        return '%41|0|0'
    if args[1] == 'capture-pane':
        # Focus switches immediately after metadata; exact targets stay stable.
        return own if target == '%41' else foreign
    raise AssertionError('unexpected source operation')
source = dict(pane='%41',session='fixture',window='codex')
result['active_pane_switch_keeps_owned_capture'] = module['capture']({},source,run) == 'exact pane turn'
result['exact_pane_only'] = all(call[call.index('-t')+1] == '%41' for call in commands)
result['post_capture_identity_check'] = len(commands) >= 3 and commands[-1][1] == 'display-message'
guard = runpy.run_path(str(args.guard))
g = guard['visible_source'].__globals__
vg = g['VISIBLE']['discover'].__globals__
full = dict(source,version=2,app='codex',root=1,actor=2,root_identity='root',actor_identity='actor',socket=dict(device=1,inode=2))
prior = dict(bindings={'old':dict(full,binding_epoch='old-epoch')},active={'1:2:%41':'old'},proofs={'old':dict(kind='operator')})
def stable_run(env,*args):
    return '%41|0|0' if args[1] == 'display-message' else own
with patch.dict(g,source_bindings=lambda:prior,codex_panes=lambda env:[full],pane_source=lambda env,row:row,live=lambda *args:True,run=stable_run,thread_retired=lambda *args:False):
    with patch.dict(g['VISIBLE'],latest_user_time=lambda *args:1), patch.dict(vg,stored_turns=lambda requested:{'new':'exact pane turn'}):
        for name,retired in [('lost_prior_history_refused',False),('retired_after_user_turn_refused',True)]:
            with patch.dict(g,thread_retired=lambda *args:retired):
                try:
                    guard['visible_source']({},'new')
                except ValueError:
                    result[name] = True
                else:
                    result[name] = False
print(json.dumps(result,sort_keys=True))
if args.output:
    args.output.write_text(json.dumps(result,indent=2)+'\n')
assert all(result.values()), 'binding regressions failed'
