import json
import hashlib
import socket
import os
from pathlib import Path
import shlex
import subprocess
import cleanup_guard
cleanup_guard.install()
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
root = Path(sys.argv[1]).resolve()
assert any(root.is_relative_to(Path.home() / 'desk' / part) for part in ('lab', 'tmp'))
root.mkdir(parents=True, mode=0o700)
binary = Path(sys.argv[2]).resolve(strict=True)
socket_name = 'ccmsg-lab-private-' + str(os.getpid())


class Responses(BaseHTTPRequestHandler):
    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        with (root/'request-tools.jsonl').open('a') as stream:
            images=sum(c.get('type')=='input_image' for v in request.get('input',[]) for c in (v.get('content',[]) if isinstance(v.get('content'),list) else []) if isinstance(c,dict))
            stream.write(json.dumps(dict(case=current.name,tools=request.get('tools',[]),images=images))+'\n')
        if not request.get('tools'):
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'{"error":{"message":"isolated fixture refusal","type":"invalid_request_error"}}')
            return
        inputs = request.get('input', [])
        last_user = max((i for i, v in enumerate(inputs) if v.get('role') == 'user'), default=-1)
        last_output = max((i for i, v in enumerate(inputs) if v.get('type') == 'function_call_output'), default=-1)
        if last_output > last_user:
            item = dict(type='message', id='msg_smoke', role='assistant', status='completed', content=[dict(type='output_text', text='launch smoke complete', annotations=[])])
        else:
            code = "import os,json,runpy;from pathlib import Path;g=runpy.run_path(" + repr(str(TOOLS / 'relay-route-guard')) + ");row=dict(chain=g['ancestors'](os.getpid()));row['identities']=[g['bind'].__globals__['AGENT']['prove'](pid) for pid,*rest in row['chain'] if g['bind'].__globals__['AGENT']['prove'](pid)];\ntry: row['source']=g['bind'](dict(os.environ),os.getpid())\nexcept ValueError as error: row['refusal']=str(error)\nPath(" + repr(str(current / 'tool-proof.json')) + ").write_text(json.dumps(row))"
            item = dict(type='function_call', id='fc_smoke', call_id='call_smoke', name='exec_command', arguments=json.dumps(dict(cmd=shlex.join([sys.executable, '-c', code]), login=False, max_output_tokens=1000)), status='completed')
        response = dict(id='resp_smoke', object='response', status='completed', output=[item], usage=dict(input_tokens=1, output_tokens=1, total_tokens=2))
        events = [dict(type='response.created', response=dict(response, status='in_progress', output=[])), dict(type='response.output_item.added', output_index=0, item=dict(item, status='in_progress')), dict(type='response.output_item.done', output_index=0, item=item), dict(type='response.completed', response=response)]
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.end_headers()
        for event in events:
            self.wfile.write(('event: ' + event['type'] + '\ndata: ' + json.dumps(event) + '\n\n').encode())
        self.wfile.flush()

    def log_message(self, *args):
        pass


mock = HTTPServer(('127.0.0.1', 0), Responses)
thread = threading.Thread(target=mock.serve_forever, daemon=True)
thread.start()
home = root / 'home'
home.mkdir()
(home / 'config.toml').write_text('check_for_update_on_startup=false\nmodel="fixture"\nmodel_provider="fixture"\n[model_providers.fixture]\nname="isolated smoke"\nbase_url="http://127.0.0.1:' + str(mock.server_port) + '/v1"\nwire_api="responses"\nrequires_openai_auth=false\n')
bin_dir = root / 'bin'
bin_dir.mkdir()
(bin_dir / 'codex').symlink_to(binary)
env = dict(os.environ, CODEX_HOME=str(home), TMPDIR=str(root), PATH=str(bin_dir) + os.pathsep + os.environ['PATH'], RELAY_SMOKE_TOKEN='private-smoke-token')
for key in ('OPENAI_API_KEY', 'CODEX_API_KEY', 'CODEX_THREAD_ID', 'CODEX_SESSION_ID'):
    env.pop(key, None)
listener = root / 's'
log = (root / 'remote-server.log').open('w')
server = subprocess.Popen([str(binary), 'app-server', '--listen', 'unix://' + str(listener)], env=env, stdout=log, stderr=log)
port_socket=socket.socket()
port_socket.bind(('127.0.0.1',0))
ws_address='ws://127.0.0.1:'+str(port_socket.getsockname()[1])
port_socket.close()
ws_home=root/'ws-home'
ws_home.mkdir()
(ws_home/'config.toml').write_text((home/'config.toml').read_text())
ws_log=(root / 'remote-ws-server.log').open('w')
ws_server=subprocess.Popen([str(binary),'app-server','--listen',ws_address,'--ws-auth','capability-token','--ws-token-sha256',hashlib.sha256(env['RELAY_SMOKE_TOKEN'].encode()).hexdigest()],env=dict(env,CODEX_HOME=str(ws_home)),stdout=ws_log,stderr=ws_log)
records = []
version = subprocess.check_output([str(binary), '--version'], text=True).strip()


def tmux(*args):
    result = subprocess.run(['tmux', '-L', socket_name, '-f', '/dev/null', *args], capture_output=True, text=True, timeout=5)
    assert result.returncode == 0, result.stderr
    return result.stdout.strip()


try:
    deadline = time.monotonic() + 15
    while not listener.exists():
        assert server.poll() is None and time.monotonic() < deadline
        time.sleep(.1)
    deadline=time.monotonic()+15
    while True:
        assert ws_server.poll() is None and time.monotonic()<deadline, (root/'remote-ws-server.log').read_text()
        try:
            with socket.create_connection(('127.0.0.1',int(ws_address.rsplit(':',1)[1])),timeout=.5):
                break
        except OSError:
            time.sleep(.1)
    tmux('new-session', '-d', '-s', 'launch-smoke', '-n', 'sentinel', '-x', '160', '-y', '45', 'exec sleep 300')
    tmux('set-option', '-g', 'automatic-rename', 'off')
    cases = [('delimited-prompt', ['--', 'future-subcommand'], True), ('bare-future-command', ['--no-daemon','future-subcommand'], False), ('remote', ['--remote', 'unix://' + str(listener)], False), ('remote-token', ['--remote='+ws_address, '--remote-auth-token-env', 'RELAY_SMOKE_TOKEN'], False)]
    if len(sys.argv)>3:
        assert len(sys.argv)==5
        first,second=[str(Path(v).resolve(strict=True)) for v in sys.argv[3:]]
        cases += [('image-variadic',['--image',first,second],True), ('image-equals',['--image='+first,'--','prompt'],True), ('image-short',['-i'+first,'--','prompt'],True)]
    for name,args,local in cases:
        current = root / name
        current.mkdir()
        script = 'source ' + shlex.quote(str(TOOLS.parents[1] / 'fish/internal/codex/codex.fish')) + "; function _agent_limit; set -lx PATH $RELAY_SMOKE_BIN $PATH; printf '%s\\0' $argv > $RELAY_SMOKE_ARGV; command $argv; end; codex $argv"
        command = shlex.join(['env', '-u','OPENAI_API_KEY','-u','CODEX_API_KEY','-u','CODEX_THREAD_ID','-u','CODEX_SESSION_ID', *(key + '=' + env[key] for key in ('CODEX_HOME','TMPDIR','PATH','RELAY_SMOKE_TOKEN')), 'RELAY_SMOKE_ARGV=' + str(current / 'argv.bin'), 'RELAY_SMOKE_BIN='+str(bin_dir), 'fish', '--no-config', '-c', script, '--', '--no-alt-screen', *args])
        tmux('new-window', '-d', '-t', '=launch-smoke', '-n', name, command)
        deadline = time.monotonic() + 45
        submitted = local or name=='bare-future-command'
        while time.monotonic() < deadline:
            capture = tmux('capture-pane', '-p', '-e', '-J', '-S', '-', '-t', '=launch-smoke:=' + name)
            (current / 'capture.txt').write_text(capture)
            if 'Trust this folder?' in capture:
                tmux('send-keys', '-t', '=launch-smoke:=' + name, 'Enter')
                time.sleep(2)
            elif not submitted and 'Ask Codex to do anything' in capture:
                tmux('send-keys', '-t', '=launch-smoke:=' + name, '-l', 'private remote runtime smoke')
                time.sleep(1)
                tmux('send-keys', '-t', '=launch-smoke:=' + name, 'Enter')
                submitted = True
            if (current / 'tool-proof.json').exists() and 'launch smoke complete' in capture:
                break
            time.sleep(.5)
        else:
            raise AssertionError(('native runtime smoke timed out', name, capture))
        argv = (current / 'argv.bin').read_bytes().decode().split('\0')[:-1]
        proof = json.loads((current / 'tool-proof.json').read_text())
        assert ('--no-daemon' in argv) == (local or name=='bare-future-command'), argv
        assert ('source' in proof) == local, proof
        assert any(v['executable'][0]==str(binary) for v in proof['identities']), proof
        if local:
            assert proof['source']['app'] == 'codex'
        else:
            assert ('exact local native launch' if name=='bare-future-command' else 'shared daemon') in proof['refusal'], proof
        if name.startswith('image-'):
            counts=[v['images'] for v in map(json.loads,(root/'request-tools.jsonl').read_text().splitlines()) if v['case']==name]
            assert (2 if name=='image-variadic' else 1) in counts,(name,counts)
        records.append(dict(case=name, binary=str(binary), version=version, argv=argv, proof=proof, runtime_complete=True))
        tmux('kill-window', '-t', '=launch-smoke:=' + name)
    print('PASS real wrapper delimited prompt, bare future-command refusal and remote/token runtime tools')
finally:
    cleanup_guard.stop_label(socket_name, capture_output=True, timeout=3)
    server.terminate()
    server.wait(timeout=10)
    ws_server.terminate()
    ws_server.wait(timeout=10)
    ws_log.close()
    log.close()
    mock.shutdown()
    mock.server_close()
    thread.join(timeout=2)
    (root / 'results.json').write_text(json.dumps(records, indent=2))
    remaining = subprocess.run(['tmux', '-L', socket_name, 'list-sessions'], capture_output=True, timeout=5)
    (root / 'cleanup.json').write_text(json.dumps(dict(server_pid=server.pid, server_exit=server.returncode, ws_server_pid=ws_server.pid, ws_server_exit=ws_server.returncode, tmux_remaining=remaining.returncode == 0)))
