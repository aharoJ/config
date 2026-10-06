import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time

output = Path(sys.argv[1]).resolve()
root = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else Path(__file__).resolve().parents[1]
output.mkdir(parents=True, exist_ok=True)
socket = f'ccmsg-lab-private-{os.getpid()}'
program = output / 'pane.py'
program.write_text('import os,pathlib,sys,tty\ntty.setraw(0)\nrows=pathlib.Path(sys.argv[1]).read_text().splitlines()\nfor i,row in enumerate(rows):os.write(1,(f"\\x1b[{i+1};1H"+row).encode())\nos.write(1,(f"\\x1b[{sys.argv[3]};{sys.argv[4]}H").encode())\nwhile True:\n b=os.read(0,256)\n with open(sys.argv[2],"ab") as f:f.write(b)\n')
results = []
def tmux(*args):
    return subprocess.run(['tmux','-L',socket,'-f','/dev/null',*args],capture_output=True,text=True,check=True).stdout.strip()
try:
    for name in ['cc-title-report','cc-title-pointer']:
        meta = json.loads((root/'tests/fixtures'/f'{name}.json').read_text())
        original = (root/'tests/fixtures'/f'{name}.txt').read_text().splitlines()
        x,y,w = meta['cursor_x'],meta['cursor_y'],meta['pane_width']
        variants = [('valid',original,x,0),('history-duplicate',[('❯ '+meta['expected_payload']) if i==0 else row for i,row in enumerate(original)],x,0)]
        extra = original.copy(); extra.insert(y+1,'  human draft continuation'); variants.append(('continuation',extra[:51],x,3))
        for label,index,value in [('upper-border',y-1,'unproven titled boundary'),('closing-border',y+1,'human draft replacing divider'),('draft-suffix',y,original[y]+' human draft')]:
            changed = original.copy(); changed[index]=value; variants.append((label,changed,x,3))
        variants.append(('moved-cursor',original,x+1,3))
        for label,rows,cursor_x,expected in variants:
            folder=output/(name+'-'+label);folder.mkdir()
            capture=folder/'capture.txt';capture.write_text('\n'.join(rows)+'\n')
            receipt=folder/'receipt';payload=folder/'payload';payload.write_text(meta['expected_payload'])
            session='lab-enter-'+str(len(results))
            tmux('new-session','-d','-s',session,'-n','claude','-x',str(w),'-y','51',shlex.join(['exec',sys.executable,str(program),str(capture),str(receipt),str(y+1),str(cursor_x+1)]))
            tmux('set-option','-w','-t',session+':claude','automatic-rename','off')
            pane=tmux('list-panes','-t',session+':claude','-F','#{pane_id}')
            for _ in range(100):
                if tmux('display-message','-p','-t',pane,'#{cursor_x}:#{cursor_y}')==f'{cursor_x}:{y}':break
                time.sleep(.01)
            pid,command=tmux('display-message','-p','-t',pane,'#{pane_pid}:#{pane_current_command}').split(':')
            socket_path=tmux('display-message','-p','-t',pane,'#{socket_path}')
            assignments=dict(TMUX_BIN='tmux',TIMEOUT_BIN=shutil.which('timeout') or shutil.which('gtimeout'),relay_script_dir=str(root/'tools'),TMUX_TIMEOUT_SECONDS='2',TMUX_TIMEOUT_KILL_AFTER='1',pane=pane,relay_target_pid=pid,relay_target_command=command,target_session=session,relay_target_window='claude',relay_verify_width=str(w),relay_verify_height='51',relay_glyph='❯',relay_target_socket=socket_path)
            harness=folder/'atomic.sh'
            script='request() { tmux -S '+shlex.quote(socket_path)+' "$@"; }\nfail() { echo "$@" >&2; exit 1; }\nrelease_relay_lock() { :; }\n'
            script+='\n'.join(k+'='+shlex.quote(v) for k,v in assignments.items())+'\n'
            delivery=os.environ.get('RELAY_DELIVERY_TEST_SOURCE',str(root/'tools/relay-delivery.sh'))
            script+='source '+shlex.quote(delivery)+'\nrelay_payload_dir='+shlex.quote(str(folder))+'\n'
            script+='if '+shlex.quote(str(root/'tools/relay-payload-guard'))+' duplicate '+shlex.quote(str(payload))+' ❯ '+str(y)+' < '+shlex.quote(str(capture))+'; then relay_enter_duplicate=1; fi\n'
            deliver='send-keys -t '+pane+' Enter ; display-message -p -t '+pane+" '__RELAY_DELIVERED__:#{pane_id}'"
            script+='relay_atomic '+shlex.quote(deliver)+' '+str(x)+' '+str(y)+' '+shlex.quote(str(payload))+'\nstatus=$?\ntrap - EXIT\nexit $status\n'
            harness.write_text(script)
            result=subprocess.run(['bash',str(harness)],capture_output=True,text=True,timeout=5)
            time.sleep(.03)
            wire=receipt.read_bytes() if receipt.exists() else b''
            entry=dict(fixture=name,attack=label,expected=expected,actual=result.returncode,wire_hex=wire.hex(),stdout=result.stdout,stderr=result.stderr)
            results.append(entry)
            (output/'results.json').write_text(json.dumps(results,indent=2)+'\n')
            assert result.returncode==expected,entry
            assert wire==(b'\r' if expected==0 else b''),entry
            tmux('kill-session','-t',session)
    (output/'results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(f'PASS: {len(results)} actual relay_atomic real-capture and derived redraw checks')
finally:
    subprocess.run(['tmux','-L',socket,'kill-server'],capture_output=True)
