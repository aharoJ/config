import json
import os
import sys
import runpy
from pathlib import Path
import subprocess
import cleanup_guard
cleanup_guard.install()
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
import threading

class FixtureResponses(BaseHTTPRequestHandler):
    def do_POST(self):
        request=json.loads(self.rfile.read(int(self.headers.get("Content-Length","0"))))
        with (root / "no-daemon-model-requests.jsonl").open("a") as out:
            out.write(json.dumps(dict(path=self.path,keys=list(request),tools=request.get("tools",[]),input_metadata=[dict(keys=list(v),role=v.get('role'),type=v.get('type'),content_type=type(v.get('content')).__name__,content_item_types=[c.get('type') for c in v.get('content',[]) if isinstance(c,dict)] if isinstance(v.get('content'),list) else []) for v in request.get('input',[])]))+"\n")
        if request.get('tools'):
            self.send_response(200)
            self.send_header('Content-Type','text/event-stream')
            self.end_headers()
            import shlex
            inputs=request.get('input',[])
            last_user=max((i for i,v in enumerate(inputs) if v.get('role')=='user'),default=-1)
            last_output=max((i for i,v in enumerate(inputs) if v.get('type')=='function_call_output'),default=-1)
            outputs=last_output>last_user
            import uuid
            token=uuid.uuid4().hex
            latest_user = str(inputs[last_user]) if last_user >= 0 else ''
            image_startup = image_options and not any(tag in latest_user for tag in ('isolated ', 'local transport launch', 'private native transport'))
            if outputs or image_startup:
                item=dict(type='message',id='msg_fixture',role='assistant',status='completed',content=[dict(type='output_text',text='native fixture complete',annotations=[])])
            else:
                code="import os,json,runpy;from pathlib import Path;g=runpy.run_path("+repr(str(TOOLS/'relay-route-guard'))+");w=runpy.run_path("+repr(str(TOOLS/'relay-reply-warning'))+");p=os.getpid();e=dict(os.environ);source=g['bind'](e,p);borrowed=dict(e,TMUX_PANE='%0',CODEX_THREAD_ID='00000000-0000-4000-8000-000000000099',CODEX_SESSION_ID='00000000-0000-4000-8000-000000000099');spoof=g['bind'](borrowed,p);assert source==spoof;row=dict(pid=p,thread=e.get('CODEX_THREAD_ID'),chain=g['ancestors'](p),source=source,borrowed_source=spoof,warning=w['reply_warning'](e,source['session'],source['window']));Path("+repr(str(root/'no-daemon-swarm-proofs.jsonl'))+").open('a').write(json.dumps(row)+'\\n')"
                content=inputs[last_user].get('content',[]) if last_user>=0 else []
                latest_text=content if isinstance(content,str) else ''.join(v.get('text','') for v in content if isinstance(v,dict))
                target='red' if latest_text.strip()=='local transport launch' else 'blue' if 'private native transport ping' in latest_text else None
                if target:
                    payload='private native transport ping' if target=='red' else 'private native transport pong'
                    code+=";import subprocess;r=subprocess.run("+repr([str(TOOLS/'relay'),'binding-fixture:'+target,payload])+",env=dict(e,CC_MSG_INBOX_ROOT="+repr(str(root/'inbox'))+",TMUX_RELAY_LOCK_ROOT="+repr(str(root/'locks'))+"),capture_output=True,text=True,timeout=45);Path("+repr(str(root/('transport-'+target+'.json')))+").write_text(json.dumps(dict(code=r.returncode,stdout=r.stdout,stderr=r.stderr)));assert r.returncode in (0,6),r.stderr"
                cmd=shlex.join(['python3','-c',code])
                item=dict(type='function_call',id='fc_'+token,call_id='call_'+token,name='exec_command',arguments=json.dumps(dict(cmd=cmd,login=False,shell='/bin/zsh',max_output_tokens=1000)),status='completed')
            response=dict(id='resp_fixture',object='response',status='completed',output=[item],usage=dict(input_tokens=1,output_tokens=1,total_tokens=2))
            events=[dict(type='response.created',response=dict(response,status='in_progress',output=[])),dict(type='response.output_item.added',output_index=0,item=dict(item,status='in_progress')),dict(type='response.output_item.done',output_index=0,item=item),dict(type='response.completed',response=response)]
            for event in events:
                self.wfile.write(('event: '+event['type']+'\ndata: '+json.dumps(event)+'\n\n').encode())
            self.wfile.flush()
        else:
            body=b'{"error":{"message":"isolated fixture refusal","type":"invalid_request_error","code":"fixture"}}'
            self.send_response(400)
            self.send_header("Content-Type","application/json")
            self.send_header("Content-Length",str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    def log_message(self,*args):
        pass
mock=HTTPServer(("127.0.0.1",0),FixtureResponses)
mock_thread=threading.Thread(target=mock.serve_forever,daemon=True)
mock_thread.start()

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
root = Path(sys.argv[1]).resolve()
assert any(root.is_relative_to(Path.home()/'desk'/part) for part in ('lab','tmp'))
root.mkdir(parents=True,mode=0o700)
binary = str(Path(sys.argv[2]).resolve(strict=True))
identity = runpy.run_path(str(TOOLS/'relay-agent-identity'))
assert identity['installation'](Path(binary)) == 'codex'
identity['stamp'](Path(binary))
image_options = []
if len(sys.argv) > 3:
    assert sys.argv[3] == '--variadic-images'
    import struct
    import zlib
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 2, 2, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b'\x00' + b'\xff\x00\x00'*2 + b'\x00' + b'\x00\xff\x00'*2)) + chunk(b'IEND', b'')
    files = [root/'one.png', root/'two.png']
    for image in files:
        image.write_bytes(png)
    image_options = ['--image', *map(str, files)]
home = root / 'no-daemon-swarm-home'
home.mkdir(exist_ok=True)
(home / 'config.toml').write_text('check_for_update_on_startup=false\nmodel_provider="fixture"\nmodel="fixture-model"\n[model_providers.fixture]\nname="isolated fixture"\nbase_url="http://127.0.0.1:PORT/v1"\nwire_api="responses"\nrequires_openai_auth=false\n'.replace('PORT',str(mock.server_port)))
records = []
import shlex
socket_name = 'ccmsg-lab-private-'+str(os.getpid())
def tmux(*args):
    r=subprocess.run(['tmux','-L',socket_name,'-f','/dev/null',*args],capture_output=True,text=True,timeout=5)
    if r.returncode: raise RuntimeError(r.stderr)
    return r.stdout.strip()
try:
    command=shlex.join(['exec','env','-u','OPENAI_API_KEY','-u','CODEX_API_KEY','-u','CODEX_THREAD_ID','-u','CODEX_SESSION_ID','CODEX_HOME='+str(home),'TMPDIR='+str(root),binary,'--no-daemon','--no-alt-screen','--ask-for-approval','never','--sandbox','danger-full-access',*image_options])
    tmux('new-session','-d','-s','binding-fixture','-n','sentinel','-x','160','-y','45','exec sleep 600')
    tmux('set-option','-g','remain-on-exit','on')
    tmux('set-option','-g','automatic-rename','off')
    tmux('new-window','-d','-t','=binding-fixture','-n','blue',command)
    time.sleep(4)
    def capture(name, seat='blue', scroll=False):
        args=['capture-pane','-p','-e','-J','-t','=binding-fixture:='+seat]
        if scroll: args+=['-S','-']
        value=tmux(*args)
        (root/('local-swarm-'+name+'.txt')).write_text(value)
        pid=tmux('display-message','-p','-t','=binding-fixture:='+seat,'#{pane_pid}')
        actor=subprocess.check_output(['ps','-p',pid,'-o','lstart=,comm='],text=True).strip()
        fds=subprocess.run(['lsof','-a','-p',pid,'-U'],capture_output=True,text=True).stdout
        records.append(dict(case=name,seat=seat,pid=int(pid),generation=actor,unix_fds=fds,capture=value))
        (root / 'no-daemon-processes.txt').write_text(subprocess.check_output(['ps','-ax','-o','pid=,ppid=,pgid=,tpgid=,command='],text=True))
        return value
    def submit(text, seat='blue'):
        tmux('send-keys','-t','=binding-fixture:='+seat,'-l',text)
        time.sleep(1)
        tmux('send-keys','-t','=binding-fixture:='+seat,'Enter')
        time.sleep(4)
    fresh=capture('fresh-blue')
    if 'Trust this folder?' in fresh:
        tmux('send-keys','-t','=binding-fixture:=blue','Enter')
        time.sleep(3)
    submit('/status')
    capture('fresh-status')
    submit('isolated native fixture A')
    capture('first-task')
    submit('/status')
    capture('first-status',scroll=True)
    proofs=lambda:[json.loads(line) for line in (root/'no-daemon-swarm-proofs.jsonl').read_text().splitlines()]
    first=proofs()[-1]['thread']
    resume=shlex.join(['exec','env','-u','OPENAI_API_KEY','-u','CODEX_API_KEY','-u','CODEX_THREAD_ID','-u','CODEX_SESSION_ID','CODEX_HOME='+str(home),'TMPDIR='+str(root),binary,'--no-daemon','--no-alt-screen','--ask-for-approval','never','--sandbox','danger-full-access','resume',first,*image_options])
    tmux('new-window','-d','-t','=binding-fixture','-n','red',resume)
    time.sleep(8)
    locked=capture('resume-before-input','red',True)
    assert 'This conversation is open in another app' in locked
    tmux('send-keys','-t','=binding-fixture:=red','f')
    time.sleep(2)
    text=tmux('capture-pane','-p','-t','=binding-fixture:=red')
    if 'Where should' in text:
        tmux('send-keys','-t','=binding-fixture:=red','Enter')
    time.sleep(3)
    capture('resume-fork-selection','red',True)
    submit('isolated duplicate resume fixture','red')
    capture('duplicate-resume','red',True)
    submit('/new')
    time.sleep(4)
    picker=capture('new-before-input','blue',True)
    assert 'Where should the new conversation run?' in picker
    tmux('send-keys','-t','=binding-fixture:=blue','Enter')
    time.sleep(3)
    submit('isolated reset fixture B')
    capture('new-task','blue',True)
    submit('isolated old thread fixture C','red')
    capture('other-seat-retains-first','red',True)
    tmux('resize-window','-t','=binding-fixture:=blue','-y','8')
    time.sleep(2)
    submit('/status')
    submit('isolated scroll fixture D')
    capture('scrolled-out-task')
    tmux('kill-window','-t','=binding-fixture:=red')
    tmux('new-window','-d','-t','=binding-fixture','-n','red',command)
    time.sleep(3)
    submit('/status','red')
    submit('isolated replacement name fixture E','red')
    capture('name-reuse','red',True)
    rows=proofs()
    assert len(rows)==6, [(r['thread'],r['source']['window']) for r in rows]
    assert all(r['source']==r['borrowed_source'] and r['warning'] is None for r in rows),rows
    a,b,c,d,e,f=rows
    assert a['source']['window']=='blue' and b['source']['window']=='red'
    assert a['thread']!=b['thread']==d['thread']
    assert 'Thread forked from '+a['thread'] in (root/'local-swarm-duplicate-resume.txt').read_text()
    assert c['thread']==e['thread']!=a['thread']
    assert a['source']['actor']==c['source']['actor']==e['source']['actor']
    assert b['source']['actor']==d['source']['actor']!=f['source']['actor']
    assert f['source']['pane']!=b['source']['pane']
    (root/'no-daemon-swarm-assertions.json').write_text(json.dumps(dict(native=binary,proofs=len(rows),fresh=True,duplicate_resume_locked=True,selected_fork=True,same_actor_new=True,scrolled_out=True,name_reuse=True,borrowed_hints_refused=True,no_reply_warnings=True),indent=2))
    tmux('resize-window','-t','=binding-fixture:=blue','-y','45')
    time.sleep(2)
    submit('local transport launch')
    until=time.monotonic()+45
    while time.monotonic()<until:
        delivered=[]
        for path in (root/'inbox').glob('*/*.json'):
            value=json.loads(path.read_text())
            if value.get('state')=='delivered':delivered.append(value)
        if len(delivered)==2 and len(proofs())>=9:
            break
        time.sleep(.5)
    assert len(delivered)==2,[(p.name,json.loads(p.read_text()).get('state')) for p in (root/'inbox').glob('*/*.json')]
    assert {v['source']['window'] for v in delivered}=={'blue','red'},delivered
    assert {v['window'] for v in delivered}=={'blue','red'},delivered
    assert not any(v.get('reply_warning') for v in delivered),delivered
    assert all(v['source']['app']=='codex' and 'thread_id' not in v['source'] for v in delivered),delivered
    capture('native-ping-received','red',True)
    capture('native-pong-received','blue',True)
    (root/'native-roundtrip.json').write_text(json.dumps(dict(delivered=len(delivered),proofs=len(proofs()),source_actors=[v['source']['actor'] for v in delivered],reply_warnings=False),indent=2))
    if image_options:
        requests=[json.loads(line) for line in (root/'no-daemon-model-requests.jsonl').read_text().splitlines()]
        assert any(sum(v['content_item_types'].count('input_image') for v in r['input_metadata'])==2 for r in requests),requests
    print('PASS six native lifecycle cases and actual guarded native relay round trip; no manual binds')
finally:
    cleanup_guard.stop_label(socket_name, capture_output=True, text=True, timeout=3)
    mock.shutdown()
    mock.server_close()
    mock_thread.join(timeout=2)
    (root/'no-daemon-swarm-responses.json').write_text(json.dumps(records,indent=2))
    check=subprocess.run(['tmux','-L',socket_name,'list-sessions'],capture_output=True,text=True,timeout=5)
    (root/'no-daemon-swarm-cleanup.json').write_text(json.dumps(dict(tmux_socket=socket_name,tmux_remaining=check.returncode==0)))
