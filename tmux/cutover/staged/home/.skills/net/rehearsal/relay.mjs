import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {read,parse,sha,hash,fileHash} from './common.mjs';

const id=/^[a-f0-9]{32}$/;
const same=(a,b)=>hash(a)===hash(b);
const exact=(o,keys)=>o&&typeof o==='object'&&!Array.isArray(o)&&same(Object.keys(o).sort(),keys.slice().sort());
const normalized=s=>s.split(/[\s\u001c-\u001f]+/u).filter(Boolean).join(' ');
const codes=s=>[...s.matchAll(/#([A-Za-z0-9_-]+)/g)].map(m=>m[1]);
const safeNumber=n=>Number.isSafeInteger(n)&&n>=0;

export function validateTransport(t){
 const keys=['version','transport','package','relay','send','store','socket','inbox'];
 if(!exact(t,keys)||t.version!=='relay-package-1'||!['rust-v1','python-v1'].includes(t.transport)||!path.isAbsolute(t.package)||t.package!==fs.realpathSync(t.package)||t.relay!==path.join(t.package,'bin/relay')||t.send!==path.join(t.package,'bin/cc-msg')||!path.isAbsolute(t.socket)||!path.isAbsolute(t.transport==='rust-v1'?t.store:t.inbox)||t.transport==='rust-v1'&&t.inbox!==null||t.transport==='python-v1'&&t.store!==null)throw Error('Invalid immutable relay transport');
 if(!same(read(path.join(t.package,'transport.json')),t))throw Error('Recorded relay package metadata changed');
 for(const command of [t.relay,t.send])if(!fs.realpathSync(command).startsWith(t.package+path.sep))throw Error('Relay command escaped immutable package');
 return t;
}

export function resolveRelay(helper=path.join(process.env.HOME,'.local/bin/cc-msg')){
 return validateTransport(read(path.join(path.dirname(fs.realpathSync(helper)),'transport.json')));
}

export function relayEnvironment(t,env=process.env){
 validateTransport(t);
 const result={...env};
 if(t.transport==='python-v1'&&result.ANGELSTAR_RELAY_STORE)throw Error('Unexpected Rust store for Python send');
 const values=t.transport==='rust-v1'?{ANGELSTAR_RELAY_STORE:t.store,ANGELSTAR_RELAY_SOCKET:t.socket}:{CC_MSG_INBOX_ROOT:t.inbox,ANGELSTAR_RELAY_SOCKET:t.socket};
 for(const [key,value] of Object.entries(values)){if(key in result&&result[key]!==value)throw Error('Relay environment mismatch: '+key);result[key]=value;}
 if(result.TMUX&&result.TMUX.split(',')[0]!==t.socket)throw Error('Relay caller socket mismatch');
 result.TMUX=result.TMUX??t.socket+',0,0';
 return result;
}

export const socketExec=(socket,exec=spawnSync)=>(command,args,options={})=>exec(command,command==='tmux'?['-S',socket,...args]:args,{...options,timeout:5000});

export function inspectRelay(t,verb,identifier,kind,exec=spawnSync){
 validateTransport(t);
 if(!id.test(identifier)||!['status','read'].includes(verb)||verb==='read'&&(t.transport!=='rust-v1'||!['original','wire'].includes(kind)))throw Error('Read-only relay operation refused');
 const args=[verb,identifier,...(verb==='read'?[kind]:[])];
 const env=relayEnvironment(t,{});
 const environment={...process.env,...env};
 if(t.transport==='python-v1')delete environment.ANGELSTAR_RELAY_STORE;
 else delete environment.CC_MSG_INBOX_ROOT;
 const r=exec(t.relay,args,{env:environment,encoding:'utf8',timeout:5000});
 if(r.status!==0||r.error||typeof r.stdout!=='string')throw Error('Recorded relay inspection failed');
 return r.stdout;
}

const generationScript=`import ctypes,json,sys
class B(ctypes.Structure):
 _fields_=[('head',ctypes.c_uint32*12),('command',ctypes.c_char*16),('name',ctypes.c_char*32),('tail',ctypes.c_uint32*6),('seconds',ctypes.c_uint64),('micros',ctypes.c_uint64)]
f=ctypes.CDLL('/usr/lib/libproc.dylib').proc_pidinfo
f.argtypes=[ctypes.c_int,ctypes.c_int,ctypes.c_uint64,ctypes.c_void_p,ctypes.c_int]
out=[]
for p in sys.argv[1:]:
 p=int(p);b=B()
 if not 0<p<2**31 or f(p,3,0,ctypes.byref(b),ctypes.sizeof(b))!=136 or b.head[3]!=p or b.head[1]==5 or not b.seconds or b.micros>=1000000:raise ValueError('process generation unavailable')
 out.append(b.seconds*1000000+b.micros)
print(json.dumps(out))`;

export function observePeer(target,t,exec=spawnSync){
 validateTransport(t);
 const socket=fs.lstatSync(t.socket);
 if(!socket.isSocket()||fs.realpathSync(t.socket)!==t.socket)throw Error('Relay socket identity unavailable');
 const r=exec('/opt/homebrew/bin/tmux',['-S',t.socket,'list-panes','-a','-F','#{session_name}\t#{window_name}\t#{session_id}\t#{window_id}\t#{pane_id}\t#{pane_pid}\t#{pid}'],{encoding:'utf8',timeout:5000});
 if(r.status!==0||r.error)throw Error('Relay peer observation failed');
 const rows=r.stdout.trim().split('\n').map(x=>x.split('\t')).filter(x=>x[0]===target.tmux_session&&x[1]===target.tmux_window&&x[4]===target.pane_id&&x[5]===target.pane_pid);
 if(rows.length!==1||!/^\$\d+$/.test(rows[0][2])||!/^@\d+$/.test(rows[0][3])||!/^%\d+$/.test(rows[0][4]))throw Error('Relay peer target changed');
 const row=rows[0],g=exec('/usr/bin/python3',['-c',generationScript,row[6],row[5]],{encoding:'utf8',timeout:5000});
 if(g.status!==0||g.error)throw Error('Relay peer generation unavailable');
 const generations=parse(g.stdout),after=fs.lstatSync(t.socket);
 if(!Array.isArray(generations)||generations.length!==2||generations.some(n=>!safeNumber(n)||!n)||socket.dev!==after.dev||socket.ino!==after.ino)throw Error('Relay peer generation changed');
 return {socket_device:socket.dev,socket_inode:socket.ino,server_generation:generations[0],session:Number(row[2].slice(1)),window:Number(row[3].slice(1)),pane:Number(row[4].slice(1)),pane_generation:generations[1]};
}

export function sourceGeometry(receipt,exec=spawnSync){
 const r=exec('tmux',['list-panes','-a','-F','#{session_name}\t#{window_name}\t#{pane_id}\t#{pane_width}\t#{pane_pid}'],{encoding:'utf8',timeout:5000});
 if(r.status!==0||r.error)throw Error('Relay geometry unavailable');
 const rows=r.stdout.trim().split('\n').map(x=>x.split('\t')),targets=rows.filter(x=>x[0]===receipt.tmux_session&&x[1]===receipt.tmux_window&&x[2]===receipt.target.pane_id);
 if(targets.length!==1)throw Error('Relay geometry target changed');
 const ps=exec('ps',['-axo','pid=,ppid='],{encoding:'utf8',timeout:5000});if(ps.status!==0||ps.error)throw Error('Relay source ancestry unavailable');
 const parents=new Map(ps.stdout.trim().split('\n').map(line=>line.trim().split(/\s+/).map(Number)));let pid=process.pid,origin=[];
 while(pid>1&&parents.has(pid)){const matches=rows.filter(x=>x[4]===String(pid));if(matches.length===1){origin=matches;break;}pid=parents.get(pid);}
 if(!origin.length&&process.env.TMUX_PANE)origin=rows.filter(x=>x[2]===process.env.TMUX_PANE);
 if(process.env.TMUX_PANE&&origin.length!==1)throw Error('Relay source unavailable');
 const label=origin.length?origin[0][1]+' ('+origin[0][0]+':'+origin[0][1]+')':'relay';
 return {width:Number(targets[0][3]),label};
}

export function bindRelay(target,label,t=resolveRelay(),peer=observePeer){
 if(typeof label!=='string'||!label||!/^[\x20-\x7e]+$/.test(label))throw Error('Relay label missing');
 return {transport:validateTransport(t),label,peer:t.transport==='rust-v1'?peer(target,t):null};
}

function announcement(stdout){
 const a=parse(stdout);
 if(!exact(a,['attempt','archive','state','peer','submission','receipt'])||!id.test(a.attempt)||!id.test(a.archive)||!['submitted','terminal-no-input','pending-no-input','input-intent','pasted','waiting-for-focus-release','submit-intent','input-unknown'].includes(a.state)||a.submission!==(a.state==='submitted'?'proved':'unproved')||a.receipt!=='unproved'||!exact(a.peer,['socket_device','socket_inode','server_generation','session','window','pane','pane_generation'])||Object.values(a.peer).some(n=>!safeNumber(n))||!a.peer.server_generation||!a.peer.pane_generation)throw Error('Invalid Rust relay announcement');
 return a;
}

function fullWire(wire,task,label,kind,identifier){
 const text=normalized(task),prefix=label+': ';
 if(!wire.startsWith(prefix))throw Error('Relay sender label mismatch');
 const body=wire.slice(prefix.length);
 if(codes(text).length){if(body!==text)throw Error('Relay explicit task/code mismatch');}
 else if(kind==='python-v1'){if(body!=='#'+identifier.slice(0,6)+' '+text)throw Error('Legacy relay task/code mismatch');}
 else if(!/^#r[a-f0-9]{12} /.test(body)||body.slice(15)!==text)throw Error('Rust relay task/code mismatch');
 return wire;
}

export function deliveryEvidence(result,binding,task,target,{exec=spawnSync}={}){
 const t=validateTransport(binding.transport);
 if(result.error)throw Error('Relay process failed: '+result.error.message);
 if(t.transport==='rust-v1'){
  const a=announcement(result.stdout);
  if(!same(a.peer,binding.peer)||a.peer.pane!==Number(target.pane_id.slice(1)))throw Error('Rust relay peer mismatch');
  const expected=a.state==='submitted'?0:a.state==='terminal-no-input'?1:a.state==='pending-no-input'?6:4;
  if(result.status!==expected)throw Error('Rust relay exit/state mismatch');
  const current=announcement(inspectRelay(t,'status',a.attempt,undefined,exec));
  if(!same(a,current))throw Error('Rust relay durable status mismatch');
  if(result.status!==0)return {transport:t,announcement:a,wire:null};
  const original=inspectRelay(t,'read',a.archive,'original',exec),wire=inspectRelay(t,'read',a.archive,'wire',exec);
  if(original!==task)throw Error('Rust relay original task mismatch');
  fullWire(wire,task,binding.label,t.transport,a.attempt);
  return {transport:t,announcement:a,wire,wire_hash:sha(wire),original_hash:sha(original)};
 }
 const match=result.stdout?.match(/^relay: ([a-f0-9]{32}) ([a-z]+); record ([^\r\n]+)\n?$/);
 if(!match)throw Error('Invalid legacy relay announcement');
 const recordPath=match[3],r=read(recordPath),peer=r.target;
 if(!path.isAbsolute(recordPath)||!recordPath.startsWith(t.inbox+path.sep)||r.id!==match[1]||r.state!==match[2]||peer?.session_name!==target.tmux_session||peer.window_name!==target.tmux_window||peer.pane_id!==target.pane_id||peer.pane_pid!==target.pane_pid||r.operator!==false||r.literal!==false||r.label!==binding.label)throw Error('Legacy relay task/target mismatch');
 if(result.status!==0||r.state!=='delivered')throw Error('Legacy relay submission unproved');
 const wire=fullWire(r.payload,task,binding.label,t.transport,r.id);
 if(r.message!==wire.slice(r.label.length+2))throw Error('Legacy relay message mismatch');
 return {transport:t,legacy_id:r.id,record_path:recordPath,record_hash:fileHash(recordPath),wire,wire_hash:sha(wire),original_hash:sha(task)};
}

export function recordedDelivery(delivery,binding,task,target,options={}){
 const evidence=deliveryEvidence(delivery,binding,task,target,options);
 if(!delivery.relay||!same(evidence,delivery.relay))throw Error('Recorded relay evidence changed');
 if(!evidence.wire)throw Error('Relay submission not proved');
 return evidence.wire;
}

export function legacyRecordedDelivery(delivery,task,target,label,{allowPointer=false}={}){
 const match=delivery.stdout?.match(/^relay: ([a-f0-9]{32}) delivered; record ([^\r\n]+)\n?$/);
 if(delivery.status!==0||!match)throw Error('Legacy relay evidence missing');
 const r=read(match[2]),p=r.target;
 if(r.id!==match[1]||r.state!=='delivered'||r.operator!==false||r.literal!==false||p?.session_name!==target.tmux_session||p.window_name!==target.tmux_window||p.pane_id!==target.pane_id||p.pane_pid!==target.pane_pid||typeof r.label!=='string'||label!==undefined&&r.label!==label)throw Error('Legacy relay task/target mismatch');
 const full=r.label+': '+r.message;
 fullWire(full,task,r.label,'python-v1',r.id);
 if(r.payload===full)return full;
 const pointer=r.label+': '+[...new Set(codes(r.message))].map(c=>'#'+c).join(' ')+' -- full: ~/desk/tmp/relay/'+r.id.slice(0,8)+'.md';
 if(!allowPointer||r.payload!==pointer||fs.readFileSync(path.join(process.env.HOME,'desk/tmp/relay',r.id.slice(0,8)+'.md'),'utf8')!==full+'\n')throw Error('Legacy relay payload mismatch');
 return pointer;
}
