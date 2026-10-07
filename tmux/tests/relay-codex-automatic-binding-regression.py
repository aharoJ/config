#!/usr/bin/env python3
import json
import os
from pathlib import Path
import runpy
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
FIRST = '00000000-0000-4000-8000-000000000001'
SECOND = '00000000-0000-4000-8000-000000000002'
OTHER = '00000000-0000-4000-8000-000000000003'

C = r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <sys/wait.h>
char value[1024];
int claude;
void draw(const char *path, int status) {
    if(claude) {
        printf("\033[2J\033[H\033[38;5;246m");for(int i=0;i<167;i++)printf("─");
        printf("\033[39m\n\033[1m❯\033[0m %s\n\033[38;5;246m",value[0]?value:"\033[2mTry asking a question\033[0m");
        for(int i=0;i<167;i++)printf("─");printf("\033[39m\n  \033[38;5;246mOpus 5.5 | context 0 | effort low | v2.1.290\033[39m\033[2;%dH",(int)strlen(value)+3);fflush(stdout);return;
    }
    char thread[80]; FILE *f=fopen(path,"r"); fgets(thread,sizeof(thread),f); fclose(f); thread[strcspn(thread,"\r\n")]=0;
    printf("\033[2J\033[H");
    if(status) printf("\033[35m/status\033[39m\n\n  \033[38;2;99;168;248m>_ \033[1m\033[39mOpenAI Codex\033[0;2m (v0.160.1)\033[0m\n\n\033[2m  Server:                     \033[0mLocal background server\n\033[2m  Model:                      \033[0mGPT-6.1-Sol\n\033[2m  Session:                    \033[0m%s\n\n",thread);
    printf("%s\n\n\033[48;2;57;57;71m\n\033[1m›\033[0m\033[48;2;57;57;71m %s\n\n\033[49m  \033[38;2;135;140;164mFast off · GPT-6.1-Sol low · ~/fixture · Context 0%% used\033[39m",getenv("BINDING_TEST_IDLE")?"":"• Working (1s • esc to interrupt)",value[0]?value:"\033[2mAsk Codex to do anything\033[0m");
    printf("\033[%d;%dH",status?12:4,(int)strlen(value)+3); fflush(stdout);
}
int main(int argc,char **argv) {
    if(!strcmp(argv[1],"app-server")) {
        char request[80];
        while(fgets(request,sizeof(request),stdin)) {
            request[strcspn(request,"\r\n")]=0;
            int pid=fork();
            if(!pid) {setenv("CODEX_THREAD_ID",request,1);setenv("CODEX_SESSION_ID",request,1);execlp("python3","python3",argv[2],NULL);_exit(99);}
            int status;waitpid(pid,&status,0);printf("__DONE__:%d\n",WEXITSTATUS(status));fflush(stdout);
        }
        return 0;
    }
    claude=strstr(argv[0],"/claude")!=NULL;
    struct termios t; tcgetattr(0,&t); t.c_lflag &= ~(ICANON|ECHO); t.c_iflag &= ~ICRNL; tcsetattr(0,TCSANOW,&t);
    draw(argv[1],0); int c,status=0,n=0;
    while((c=getchar())!=EOF) {
        if(c=='\r'||c=='\n') {
            FILE *f=fopen(argv[2],"a"); fprintf(f,"%s\n",value); fclose(f);
            status=!strcmp(value,"/status"); value[0]=0;n=0; if(status) for(int i=0;i<40;i++) putchar('\n');
        } else if(c==21) {n=0;value[0]=0;} else {value[n++]=c;value[n]=0;}
        draw(argv[1],status);
    }
}
'''


def run(output):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    tools = output / 'tools'
    shutil.copytree(ROOT / 'tools', tools)
    bindings = output / 'bindings.json'
    logs = output / 'logs.sqlite'
    guard = tools / 'relay-route-guard'
    text = guard.read_text()
    text = text.replace("SOURCE_BINDINGS = pathlib.Path(pwd.getpwuid(os.getuid()).pw_dir) / '.local/state/relay/source-bindings.json'", 'SOURCE_BINDINGS = pathlib.Path(' + repr(str(bindings)) + ')')
    text = text.replace("RUNTIME_LOGS = pathlib.Path(pwd.getpwuid(os.getuid()).pw_dir) / '.codex/logs_2.sqlite'", 'RUNTIME_LOGS = pathlib.Path(' + repr(str(logs)) + ')')
    text = text.replace("    args = parser.parse_args()", "    args = parser.parse_args()\n    if not args.record and os.environ.get('BINDING_TEST_DISCOVERY_DELAY'):\n        time.sleep(float(os.environ['BINDING_TEST_DISCOVERY_DELAY']))")
    guard.write_text(text)
    database = sqlite3.connect(logs)
    database.execute('CREATE TABLE logs (ts INTEGER, ts_nanos INTEGER, feedback_log_body TEXT, thread_id TEXT, target TEXT)')
    database.commit()
    (output / 'fixture.c').write_text(C)
    subprocess.run(['cc', str(output / 'fixture.c'), '-o', str(output / 'codex')], check=True)
    socket = 'ccmsg-lab-private-binding8-' + str(os.getpid())
    wrapper = output / 'tmux-private'
    wrapper.write_text('#!/bin/sh\nexec tmux -L ' + socket + ' -f /dev/null "$@"\n')
    wrapper.chmod(0o700)
    def tmux(*args):
        return subprocess.check_output([str(wrapper), *args], text=True, timeout=10).strip()
    daemon = None
    try:
        for seat, thread in [('codex', FIRST), ('terra', OTHER)]:
            (output / (seat + '.thread')).write_text(thread + '\n')
            command = 'exec ' + str(output / 'codex') + ' ' + str(output / (seat + '.thread')) + ' ' + str(output / (seat + '.input'))
            if seat == 'codex':
                tmux('new-session', '-d', '-s', 'config', '-n', seat, '-x', '167', '-y', '30', command)
            else:
                tmux('new-window', '-d', '-t', 'config', '-n', seat, command)
            tmux('set-option', '-w', '-t', '=config:=' + seat, 'automatic-rename', 'off')
        env = dict(os.environ, TMUX=tmux('display-message', '-p', '-t', '=config:=codex', '#{socket_path},#{pid},0'), TMUX_BIN=str(wrapper), TMUX_RELAY_LOCK_ROOT=str(output / 'locks'))
        module = runpy.run_path(str(guard))
        g = module['automatic_source'].__globals__
        original_run = subprocess.run
        def traced_run(*args, **kwargs):
            result = original_run(*args, **kwargs)
            if 'relay-codex-source-probe' in str(args[0]):
                print('PROBE', result.returncode, result.stdout.strip(), result.stderr.strip(), flush=True)
            return result
        subprocess.run = traced_run
        first = module['automatic_source'](env, FIRST)
        assert first['window'] == 'codex' and first['thread_id'] == FIRST, first
        assert module['live'](env, first)
        print('PASS initial launch proves native current status without operator registration', flush=True)
        again = module['automatic_source'](env, FIRST)
        assert again['binding_epoch'] == first['binding_epoch']
        caller = output / 'daemon-call.py'
        caller.write_text('import runpy,os,json\nm=runpy.run_path(' + repr(str(guard)) + ')\nprint(json.dumps(m["bind"](os.environ,os.getpid())),flush=True)\n')
        stale = first['pane']
        daemon = subprocess.Popen([str(output / 'codex'), 'app-server', str(caller)], env=dict(env, TMUX_PANE=stale), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        def shared_call(thread):
            daemon.stdin.write(thread + '\n'); daemon.stdin.flush()
            result = daemon.stdout.readline()
            status = daemon.stdout.readline()
            assert status == '__DONE__:0\n', (result, status)
            return json.loads(result)
        assert shared_call(FIRST)['window'] == 'codex'
        assert shared_call(OTHER)['window'] == 'terra'
        print('PASS two native calls through one real fake-daemon PID ignore stale pane hint', flush=True)

        (output / 'codex.thread').write_text(SECOND + '\n')
        now = time.time()
        database.execute('INSERT INTO logs VALUES (?,?,?,?,?)', (int(now), int((now % 1) * 1e9), 'clearing thread listener during thread-state teardown thread_id=' + FIRST + ' listener_generation=1', FIRST, 'codex_app_server::thread_state'))
        database.commit()
        assert not module['live'](env, first)
        second = module['automatic_source'](env, SECOND)
        assert second['window'] == 'codex' and module['live'](env, second)
        assert not module['live'](env, first)
        print('PASS replacement thread retires old proof and automatically binds current native status', flush=True)
        other = module['automatic_source'](env, OTHER)
        assert other['window'] == 'terra' and module['live'](env, other)
        print('PASS simultaneous second seat retains independent current thread', flush=True)
        (output / 'terra.thread').write_text(SECOND + '\n')
        try:
            module['automatic_source'](env, SECOND)
            raise AssertionError('duplicate current thread accepted')
        except ValueError:
            pass
        print('PASS duplicate current status UUID is ambiguous and refused', flush=True)
        (output / 'codex.thread').write_text(FIRST + '\n')
        now = time.time()
        database.execute('INSERT INTO logs VALUES (?,?,?,?,?)', (int(now), int((now % 1) * 1e9), 'clearing thread listener during thread-state teardown thread_id=' + SECOND + ' listener_generation=1', SECOND, 'codex_app_server::thread_state'))
        database.commit()
        resumed = shared_call(FIRST)
        assert resumed['binding_epoch'] != first['binding_epoch'] and module['live'](env, resumed)
        assert not module['live'](env, first) and not module['live'](env, second)
        print('PASS same UUID resume receives new generation; old queued source remains retired', flush=True)
        (output / 'terra.thread').write_text(OTHER + '\n')
        row = next(row for row in module['panes'](env) if row[2] == 'codex')
        bare = module['pane_source'](env, row)
        def private_probe():
            return original_run([str(tools / 'relay-codex-source-probe')], input=json.dumps(bare), env=env, capture_output=True, text=True, timeout=12)
        tmux('send-keys', '-t', '=config:=codex', '-l', 'owned draft')
        time.sleep(.1)
        previous = (output / 'codex.input').read_text()
        assert private_probe().returncode == 1
        try:
            module['automatic_source'](env, OTHER)
            raise AssertionError('hidden possible duplicate source accepted')
        except ValueError:
            pass
        assert (output / 'codex.input').read_text() == previous
        assert 'owned draft' in tmux('capture-pane', '-p', '-t', '=config:=codex')
        tmux('send-keys', '-t', '=config:=codex', 'C-u')
        time.sleep(.1)
        print('PASS source draft preserved; no status literal or Enter requested', flush=True)
        tmux('copy-mode', '-t', '=config:=codex')
        assert private_probe().returncode == 1
        assert tmux('display-message', '-p', '-t', '=config:=codex', '#{pane_in_mode}') == '1'
        assert (output / 'codex.input').read_text() == previous
        tmux('send-keys', '-t', '=config:=codex', '-X', 'cancel')
        print('PASS copy mode preserved; fixture owner alone ends it', flush=True)
        lock = output / 'locks' / __import__('hashlib').sha256((str(bare['socket']['device']) + ':' + str(bare['socket']['inode']) + ':' + bare['pane']).encode()).hexdigest()
        lock.write_text(str(os.getpid()))
        assert private_probe().returncode == 1
        assert (output / 'codex.input').read_text() == previous
        lock.unlink()
        print('PASS existing delivery lock preserved with zero source input', flush=True)
        shutil.copy2(output / 'codex', output / 'claude')
        (output / 'claude.thread').write_text(OTHER + '\n')
        (output / 'claude.input').write_text('')
        tmux('new-window', '-d', '-t', 'config', '-n', 'claude', 'exec ' + str(output / 'claude') + ' ' + str(output / 'claude.thread') + ' ' + str(output / 'claude.input'))
        tmux('set-option', '-w', '-t', '=config:=claude', 'automatic-rename', 'off')
        tmux('resize-window', '-t', '=config:=claude', '-x', '167', '-y', '30')
        time.sleep(.1)
        tmux('send-keys', '-t', '=config:=claude', '-l', 'owned target draft')
        time.sleep(.1)
        message_caller = output / 'message-call.py'
        message_caller.write_text('import subprocess,os,json,sys\nr=subprocess.run([sys.executable,' + repr(str(tools / 'cc-msg-queue')) + ',os.environ["BINDING_TEST_MESSAGE"]],capture_output=True,text=True)\nprint(json.dumps({"code":r.returncode,"out":r.stdout,"err":r.stderr}),flush=True)\n')
        inbox = output / 'inbox'
        def send(thread, text, extra=None):
            sender = subprocess.Popen([str(output / 'codex'), 'app-server', str(message_caller)], env=dict(env, TMUX_PANE=first['pane'], CC_MSG_SESSION='config', CC_MSG_WINDOW='claude', CC_MSG_INBOX_ROOT=str(inbox), TMPDIR=str(output), BINDING_TEST_MESSAGE=text, **(extra or {})), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            stdout, stderr = sender.communicate(thread + '\n', timeout=30)
            rows = stdout.splitlines()
            assert rows[-1] == '__DONE__:0', (stdout, stderr)
            return json.loads(rows[0])
        queued = send(FIRST, 'standing instruction from soon retired thread')
        assert queued['code'] == 6, queued
        records = list(inbox.glob('*/*.json'))
        assert len(records) == 1 and (output / 'claude.input').read_text() == ''
        old_record = records[0]
        now = time.time()
        database.execute('INSERT INTO logs VALUES (?,?,?,?,?)', (int(now), int((now % 1) * 1e9), 'clearing thread listener during thread-state teardown thread_id=' + FIRST + ' listener_generation=1', FIRST, 'codex_app_server::thread_state'))
        database.commit()
        (output / 'codex.thread').write_text(SECOND + '\n')
        tmux('send-keys', '-t', '=config:=claude', 'C-u')
        for _ in range(200):
            record = json.loads(old_record.read_text())
            if record['state'] in ('failed', 'delivered', 'unknown'):
                break
            time.sleep(.1)
        assert record['state'] == 'failed' and record['code'] == 1, record
        assert (output / 'claude.input').read_text() == ''
        print('PASS actual queued message from reset source fails before target input', flush=True)
        sent = send(SECOND, 'fresh replacement thread receipt')
        if sent['code'] != 0:
            (output / 'fresh-target-capture.txt').write_text(tmux('capture-pane', '-p', '-e', '-t', '=config:=claude'))
            (output / 'fresh-target-state.txt').write_text(tmux('display-message', '-p', '-t', '=config:=claude', '#{cursor_x}:#{cursor_y}:#{pane_width}:#{pane_height}'))
        assert sent['code'] == 0, sent
        submitted = (output / 'claude.input').read_text().splitlines()
        assert submitted == ['codex (config:codex) [gpt-6.1-sol low]: fresh replacement thread receipt'], submitted
        print('PASS fresh replacement automatically binds and delivers exactly once through native adapters', flush=True)
        started = time.monotonic()
        delayed = send(SECOND, 'slow initial native discovery receipt', {'BINDING_TEST_DISCOVERY_DELAY': '6'})
        assert delayed['code'] == 0 and time.monotonic() - started >= 6, delayed
        submitted = (output / 'claude.input').read_text().splitlines()
        assert submitted == ['codex (config:codex) [gpt-6.1-sol low]: fresh replacement thread receipt', 'codex (config:codex) [gpt-6.1-sol low]: slow initial native discovery receipt'], submitted
        print('PASS source discovery beyond five seconds; authenticated record route checks stay fast and deliver exactly once', flush=True)
        tmux('respawn-pane', '-k', '-t', '=config:=terra', 'exec env BINDING_TEST_IDLE=1 ' + str(output / 'codex') + ' ' + str(output / 'terra.thread') + ' ' + str(output / 'terra.input'))
        time.sleep(.1)
        native_caller = output / 'native-message-call.py'
        native_caller.write_text('import subprocess,os,json,sys\nr=subprocess.run([sys.executable,' + repr(str(tools / 'cc-msg-queue')) + ',"--codex-to","terra","native recipient bound-record Enter receipt"],capture_output=True,text=True)\nprint(json.dumps({"code":r.returncode,"out":r.stdout,"err":r.stderr}),flush=True)\n')
        native_sender = subprocess.Popen([str(output / 'codex'), 'app-server', str(native_caller)], env=dict(env, CODEX_SEND_SESSION='config', CC_MSG_INBOX_ROOT=str(inbox), TMPDIR=str(output)), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = native_sender.communicate(SECOND + '\n', timeout=30)
        reply = json.loads(stdout.splitlines()[0])
        assert reply['code'] == 0, (reply, stderr)
        native_inputs = (output / 'terra.input').read_text().splitlines()
        assert native_inputs.count('codex (config:codex) [gpt-6.1-sol low]: native recipient bound-record Enter receipt') == 1, native_inputs
        print('PASS native Codex recipient uses bound-record route proof after paste and receives exactly one Enter', flush=True)
        state = json.loads(bindings.read_text())
        (output / 'results.json').write_text(json.dumps({'passed': True, 'bindings': state}, indent=2) + '\n')
    finally:
        if daemon is not None:
            daemon.stdin.close()
            daemon.wait(timeout=10)
        subprocess.run([str(wrapper), 'kill-server'], capture_output=True, timeout=10)
        database.close()


if __name__ == '__main__':
    run(sys.argv[1])
