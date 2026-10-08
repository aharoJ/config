#!/usr/bin/env python3
"""Compiled inert native actor; real tmux/process proof and private history only."""
import json
import os
import pathlib
import runpy
import shlex
import sqlite3
import subprocess
import tempfile
import time
from unittest.mock import patch

TOOLS = pathlib.Path(__file__).resolve().parents[1] / 'tools'
FIRST = '00000000-0000-4000-8000-000000000001'
SECOND = '00000000-0000-4000-8000-000000000002'
THIRD = '00000000-0000-4000-8000-000000000003'
FOURTH = '00000000-0000-4000-8000-000000000004'
FIFTH = '00000000-0000-4000-8000-000000000005'
root = pathlib.Path(tempfile.mkdtemp(prefix='rn-n-',dir=pathlib.Path.home() / 'desk/lab'))
socket = 'ccmsg-lab-private-native-' + str(os.getpid())
C = r'''
#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <string.h>
#include <sys/select.h>
int main(int argc,char **argv) {
    struct termios t; tcgetattr(0,&t); cfmakeraw(&t); tcsetattr(0,TCSANOW,&t);
    char turn[1024],last[1024]="";
    while(1) {
        FILE *f=fopen(argv[1],"r"); if(!f)return 2;
        if(!fgets(turn,sizeof(turn),f)) {fclose(f);usleep(1000);continue;}
        fclose(f); turn[strcspn(turn,"\r\n")]=0;
        if(strcmp(turn,last)) {
            printf("\033[2J\033[H› %s\r\n\r\n• Finished\r\n\r\n› Ask Codex to do anything\r\n",turn);
            fflush(stdout); strcpy(last,turn);
        }
        char c; struct timeval timeout={0,100000}; fd_set ready; FD_ZERO(&ready); FD_SET(0,&ready);
        if(select(1,&ready,0,0,&timeout)>0 && read(0,&c,1)>0) {
            FILE *wire=fopen(argv[2],"ab"); fwrite(&c,1,1,wire); fclose(wire);
        }
    }
}
'''


def tmux(*args):
    result = subprocess.run(['tmux','-L',socket,'-f','/dev/null',*args],capture_output=True,text=True,timeout=3)
    if result.returncode:
        raise ValueError(result.stderr)
    return result.stdout.strip()


def add_turn(thread,text):
    with sqlite3.connect(root / 'state.sqlite') as db:
        db.execute('INSERT OR IGNORE INTO threads VALUES (?,?,?)',(thread,str(root / 'unused.jsonl'),'paginated'))
    with sqlite3.connect(root / 'history.sqlite') as db:
        db.execute('INSERT INTO thread_items VALUES (?,?,?,?,?)',(thread,json.dumps(dict(type='userMessage',content=[dict(type='text',text=text)])), 'userMessage',time.time_ns(),int(time.time()*1000)))


def show(text,pane):
    (root / 'turn').write_text(text + '\n')
    deadline = time.monotonic() + 3
    while text not in tmux('capture-pane','-p','-t',pane):
        assert time.monotonic() < deadline
        time.sleep(.02)


def refused(call):
    try:
        call()
    except ValueError:
        return
    raise AssertionError('unsafe lifecycle evidence accepted')


try:
    # Generated fixtures live under owned lab scratch, never in session storage.
    (root / 'fixture.c').write_text(C)
    subprocess.run(['cc',str(root / 'fixture.c'),'-o',str(root / 'codex')],check=True,capture_output=True)
    (root / 'turn').write_text('first native unique turn\n')
    command = 'exec ' + shlex.quote(str(root / 'codex')) + ' ' + shlex.quote(str(root / 'turn')) + ' ' + shlex.quote(str(root / 'wire'))
    pane = tmux('new-session','-d','-s','config','-n','lala','-x','100','-y','30','-P','-F','#{pane_id}',command)
    tmux('set-option','-w','-t',pane,'automatic-rename','off')
    address = tmux('display-message','-p','-t',pane,'#{socket_path},#{pid},0')
    env = dict(os.environ,TMUX=address)
    with sqlite3.connect(root / 'state.sqlite') as db:
        db.execute('CREATE TABLE threads (id TEXT PRIMARY KEY,rollout_path TEXT,history_mode TEXT)')
    with sqlite3.connect(root / 'history.sqlite') as db:
        db.execute('CREATE TABLE thread_items (thread_id TEXT,item_json TEXT,item_type TEXT,rollout_ordinal INTEGER,created_at_ms INTEGER)')
    with sqlite3.connect(root / 'logs.sqlite') as db:
        db.execute('CREATE TABLE logs (ts INTEGER,ts_nanos INTEGER,feedback_log_body TEXT,thread_id TEXT,target TEXT)')
    for path in root.glob('*.sqlite'):
        path.chmod(0o600)
    add_turn(FIRST,'first native unique turn')
    guard = runpy.run_path(str(TOOLS / 'relay-route-guard'))
    g = guard['automatic_source'].__globals__
    g.update(SOURCE_BINDINGS=root / 'bindings.json',RUNTIME_LOGS=root / 'logs.sqlite')
    vg = g['VISIBLE']['discover'].__globals__
    vg.update(STATE=root / 'state.sqlite',HISTORY=root / 'history.sqlite',CACHE=root / 'cache.json')
    deadline = time.monotonic() + 3
    while 'first native unique turn' not in tmux('capture-pane','-p','-t',pane):
        assert time.monotonic() < deadline
        time.sleep(.02)
    started = runpy.run_path(str(TOOLS / 'relay-started-watch'))
    with patch.object(started['reply_warning'].__globals__['runpy'], 'run_path', lambda path:guard):
        assert started['reply_warning'](env,'config','lala') == 'target config:lala is unbound: it cannot reply until bound'
    guard['register_source'](env,FIRST,'config:lala')
    with patch.object(started['reply_warning'].__globals__['runpy'], 'run_path', lambda path:guard):
        assert started['reply_warning'](env,'config','lala') is None
    queue = runpy.run_path(str(TOOLS / 'cc-msg-queue'))
    target_env = dict(env, CC_MSG_SESSION='config', CC_MSG_WINDOW='lala')
    target_identity = queue['identity'](target_env)
    baseline = started['snapshot'](queue,target_env,target_identity)
    source = dict(guard['source_bindings']()['bindings'][FIRST], thread_id=FIRST)
    assert guard['check'](env, source, 'config', 'claude')
    assert not guard['check'](env, source, 'cvmapp', 'claude')
    add_turn(SECOND,'replacement native unique turn')
    (root / 'turn').write_text('replacement native unique turn\n')
    while 'replacement native unique turn' not in tmux('capture-pane','-p','-t',pane):
        assert time.monotonic() < deadline
        time.sleep(.02)
    bound = guard['automatic_source'](env,SECOND)
    assert started['snapshot'](queue,target_env,target_identity) != baseline
    assert bound['pane'] == pane and bound['thread_id'] == SECOND
    assert bound['window'] == 'lala'
    assert guard['live'](env,bound)
    assert guard['source_bindings']()['proofs'][SECOND]['kind'] == 'visible-turn'
    assert not guard['live'](env,dict(guard['source_bindings']()['bindings'][FIRST],thread_id=FIRST))
    # Resume an existing UUID with a new actual user turn, then fork it.
    add_turn(FIRST,'resumed native unique turn')
    show('resumed native unique turn',pane)
    resumed = guard['automatic_source'](env,FIRST)
    assert resumed['binding_epoch'] != bound['binding_epoch']
    add_turn(THIRD,'resumed native unique turn')
    refused(lambda:guard['automatic_source'](env,THIRD))
    add_turn(THIRD,'fork native unique turn')
    show('fork native unique turn',pane)
    forked = guard['automatic_source'](env,THIRD)
    assert not guard['live'](env,resumed)
    # Respawn the established pane, retaining socket/pane lineage while the
    # former kernel-backed process generation has actually ended.
    add_turn(FOURTH,'respawn native unique turn')
    (root / 'turn').write_text('respawn native unique turn\n')
    tmux('respawn-pane','-k','-t',pane,command)
    show('respawn native unique turn',pane)
    respawned = guard['automatic_source'](env,FOURTH)
    assert respawned['actor'] != forked['actor']
    assert guard['live'](env,respawned) and not guard['live'](env,forked)
    state = guard['source_bindings']()
    assert state['lineage'][respawned['binding_epoch']]['predecessor_epoch'] == forked['binding_epoch']
    # Losing prior history must not turn a stale/foreign screen into proof.
    with sqlite3.connect(root / 'state.sqlite') as db:
        db.execute('DELETE FROM threads WHERE id=?',(FOURTH,))
    add_turn(FIFTH,'pruned native unique turn')
    show('pruned native unique turn',pane)
    refused(lambda:guard['automatic_source'](env,FIFTH))
    assert not (root / 'wire').exists(), 'identity typed into native fixture'
    print('PASS native bootstrap/reset/resume/fork/respawn lineage, copied turns and pruned-history refusal, queued retirement; zero input bytes')
finally:
    subprocess.run(['tmux','-L',socket,'kill-server'],capture_output=True,text=True,timeout=3)
    proof = subprocess.run(['tmux','-L',socket,'list-sessions'],capture_output=True,text=True,timeout=3)
    assert proof.returncode == 1 and ('no server running' in proof.stderr or 'No such file' in proof.stderr)
