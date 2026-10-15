import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import {spawnSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {register} from 'node:module';

register('./net-loader.mjs',import.meta.url);
const base=new URL('home/.skills/net/rehearsal/',new URL('../staged/',import.meta.url));
const relay=await import(new URL('relay.mjs',base));
const {ping,pingPath}=await import(new URL('ping.mjs',base));
const {attest}=await import(new URL('attest.mjs',base));
const {dispatch,shortTask,assertInlineRelay}=await import(new URL('runner.mjs',base));
const {deliveredDispatch,checkSession,inventory}=await import(new URL('session.mjs',base));
const {sha,hash,fileHash,write}=await import(new URL('common.mjs',base));
const roots=[];
const peer={socket_device:1,socket_inode:2,server_generation:123000001,session:3,window:4,pane:7,pane_generation:456000002};
const label='claude (net:source)';
const attempt='a'.repeat(32),archive='b'.repeat(32),legacy='c'.repeat(32);

function fixture(kind='rust-v1'){
 const desk=fs.mkdtempSync(path.join(process.env.HOME,'desk/tmp/s6x-net-'));roots.push(desk);
 const root=path.join(desk,'run-preparation'),directory=path.join(root,'seat');fs.mkdirSync(path.join(directory,'out'),{recursive:true});fs.mkdirSync(path.join(root,'bootstrap'),{recursive:true});
 fs.writeFileSync(path.join(directory,'PROMPT.md'),'frozen task');
 const target={tmux_session:'net',tmux_window:'rh-ctx1',pane_id:'%7',pane_pid:'123',command:'claude',directory,process_pid:'123',process_session:'native-session',requested_model:'claude-opus-5-5',requested_effort:'medium'};
 const context={context_id:'ctx1',directory,dispatch_case_ids:['case1'],access_receipt:{session:'native-session',configuration_directory:path.join(root,'config')}};
 const packageRoot=path.join(desk,kind);fs.mkdirSync(path.join(packageRoot,'bin'),{recursive:true});fs.writeFileSync(path.join(packageRoot,'launch'),'fixture');for(const name of ['relay','cc-msg'])fs.symlinkSync('../launch',path.join(packageRoot,'bin',name));
 const t={version:'relay-package-1',transport:kind,package:packageRoot,relay:path.join(packageRoot,'bin/relay'),send:path.join(packageRoot,'bin/cc-msg'),store:kind==='rust-v1'?path.join(desk,'store'):null,inbox:kind==='python-v1'?path.join(desk,'inbox'):null,socket:process.env.TMUX?.split(',')[0]??'/private/tmp/tmux-501/default'};
 if(t.inbox)fs.mkdirSync(t.inbox);write(path.join(packageRoot,'transport.json'),t);
 const binding=relay.bindRelay(target,label,t,()=>peer);
 const announcement={attempt,archive,state:'submitted',peer,submission:'proved',receipt:'unproved'};
 const f={desk,root,directory,target,context,t,binding,announcement,task:'reply READY, read nothing',wire:'',commands:[],sends:0};
 f.render=task=>label+': '+(/#[A-Za-z0-9_-]+/.test(task)?task:(kind==='rust-v1'?'#r0123456789ab ':'#cccccc ')+task);
 f.result=(task=f.task)=>{
  f.task=task;f.wire=f.render(task);
  if(kind==='rust-v1')return {status:0,stdout:JSON.stringify(f.announcement)+'\n',stderr:''};
  const record={id:legacy,state:'delivered',label,message:f.wire.slice(label.length+2),operator:false,literal:false,payload:f.wire,target:{session_name:'net',window_name:'rh-ctx1',pane_id:'%7',pane_pid:'123'}};
  f.recordPath=path.join(t.inbox,'message.json');write(f.recordPath,record);
  return {status:0,stdout:`relay: ${legacy} delivered; record ${f.recordPath}\n`,stderr:''};
 };
 f.inspect=(command,args,options)=>{
  f.commands.push({command,args,options});assert.equal(command,t.relay);
  if(kind==='python-v1')return {status:0,stdout:legacy+' pending\n'};
  assert.equal(options.env.ANGELSTAR_RELAY_STORE,t.store);assert.equal(options.env.ANGELSTAR_RELAY_SOCKET,t.socket);
  return {status:0,stdout:args[0]==='status'?JSON.stringify(f.announcement):args[2]==='wire'?f.wire:f.task};
 };
 f.options={target:()=>target,geometry:()=>({width:300,label}),transport:()=>t,peer:()=>peer,inspect:f.inspect,send:(command,args,options)=>{f.sends++;assert.equal(command,t.send);assert.equal(options.env.CC_MSG_SESSION,'net');assert.equal(options.env.CC_MSG_WINDOW,'rh-ctx1');return f.result(args[0]);}};
 const authority=path.join(desk,'authority');fs.writeFileSync(authority,'approved fixture');write(path.join(desk,'RECEIPT-C.json'),{candidate:{effective_model:'claude-opus-5-5',billing_mode:'EXISTING_SUBSCRIPTION',account_or_seat:'fixture'}});write(path.join(desk,'CONFIGURATION-APPROVAL.json'),{status:'VERIFIED',configuration_receipt_hash:fileHash(path.join(desk,'RECEIPT-C.json')),authority_path:authority,authorization_hash:fileHash(authority)});
 const profile=path.join(root,'profile');fs.writeFileSync(profile,'fixture');f.recordsPath=path.join(root,'records.jsonl');
 f.launch={version:'net-bootstrap-1',profile_path:profile,profile_hash:fileHash(profile),source_configuration_directory:context.access_receipt.configuration_directory,context_id:'ctx1',directory,model:'claude-opus-5-5',effort:'medium',no_resume:true,no_prompt:true,tmux_window:'rh-ctx1',tmux_session:'net',session:'native-session',configuration_directory:context.access_receipt.configuration_directory,records_path:f.recordsPath,inventory_hash:inventory(directory),started_at:'2026-01-01T00:00:00Z'};
 write(path.join(root,'bootstrap/ctx1.json'),f.launch);f.prep={contexts:[context],terminal_dispositions:[]};write(path.join(root,'PREPARATION.json'),f.prep);write(path.join(root,'RUN-MANIFEST.json'),{manifest:{cases:[{case_id:'case1',attempt_id:'attempt1',packet_hash:sha('packet')}]}});
 f.startup=wire=>fs.writeFileSync(f.recordsPath,[{type:'user',sessionId:'native-session',cwd:directory,message:{content:wire}},{type:'assistant',sessionId:'native-session',message:{model:'claude-opus-5-5',content:[{type:'text',text:'READY'}]}}].map(JSON.stringify).join('\n')+'\n');
 f.seal=()=>{
  const result=ping(desk,'ctx1',f.options);assert.equal(result.status,0);f.startup(f.wire);
  const a=attest(desk,'ctx1',f.options);context.session_receipt={path:a.receipt_path,sha256:a.receipt_hash};write(path.join(root,'PREPARATION.json'),f.prep);f.receipt=JSON.parse(fs.readFileSync(a.receipt_path));return f;
 };
 return f;
}

test('Rust and Python exact ping, READY, dispatch and first native task are bound',()=>{
 for(const kind of ['rust-v1','python-v1']){
  const f=fixture(kind).seal();assert.equal(f.receipt.records_hash,fileHash(f.recordsPath));
  const sent=dispatch(f.desk,'ctx1',{...f.options,validate:()=>({valid:true})});assert.equal(sent.status,0);
  const d=deliveredDispatch(f.root,f.context,f.receipt,{inspect:f.inspect});assert.equal(d.input,f.render(shortTask));
  fs.appendFileSync(f.recordsPath,JSON.stringify({type:'user',sessionId:'native-session',cwd:f.directory,message:{content:d.input}})+'\n');assert.deepEqual(checkSession(f.receipt,f.context,{target:()=>f.target,dispatch:d}),f.target);
  assert.throws(()=>dispatch(f.desk,'ctx1',{...f.options,validate:()=>({valid:true})}),/EEXIST/);assert.equal(f.sends,2);
 }
});

test('missing, malformed, duplicate-key and old unproved exit-zero outputs never succeed',()=>{
 for(const stdout of ['', 'delivered to %7', '{}', '{"attempt":"x","attempt":"y"}', 'relay: '+legacy+' pending; record /missing\n']){
  const f=fixture();const r=ping(f.desk,'ctx1',{...f.options,send:()=>({status:0,stdout,stderr:''})});assert.equal(r.status,4);assert.equal(r.state,'FAILED_NO_RESEND');
  assert.throws(()=>attest(f.desk,'ctx1',f.options),/ping delivery/);
 }
});

test('Rust task, wire, source, code, peer, durable status and announcement mismatches fail closed',()=>{
 for(const mode of ['task','wire','source','code','peer','status','state','receipt','extra']){
  const f=fixture(),r=f.result();let inspect=f.inspect;
  if(mode==='task')f.task+=' foreign';if(mode==='wire')f.wire+=' foreign';if(mode==='source')f.wire='foreign: '+f.wire;if(mode==='code')f.wire=f.wire.replace('#r0123456789ab','#invalid');
  if(mode==='peer')r.stdout=JSON.stringify({...f.announcement,peer:{...peer,pane:8}});
  if(mode==='status')inspect=(command,args,options)=>args[0]==='status'?{status:0,stdout:JSON.stringify({...f.announcement,archive:'d'.repeat(32)})}:f.inspect(command,args,options);
  if(mode==='state')r.stdout=JSON.stringify({...f.announcement,state:'pending-no-input',submission:'unproved'});
  if(mode==='receipt')r.stdout=JSON.stringify({...f.announcement,receipt:'proved'});
  if(mode==='extra')r.stdout=JSON.stringify({...f.announcement,foreign:true});
  assert.throws(()=>relay.deliveryEvidence(r,f.binding,'reply READY, read nothing',f.target,{exec:inspect}),undefined,mode);
 }
});

test('explicit reply codes survive both transports and generated codes do not replace them',()=>{
 for(const kind of ['rust-v1','python-v1'])for(const task of ['#k7f2 Read TASK.md','#k7f2 #other Read TASK.md']){
  const f=fixture(kind),result=f.result(task);const evidence=relay.deliveryEvidence(result,f.binding,task,f.target,{exec:f.inspect});assert.equal(evidence.wire,label+': '+task);
 }
});

test('recorded Rust status/read remain pinned after rollback and Python pending uses Python',()=>{
 const rust=fixture(),python=fixture('python-v1'),result=rust.result();const evidence=relay.deliveryEvidence(result,rust.binding,rust.task,rust.target,{exec:rust.inspect});
 const pointer=path.join(rust.desk,'relay-current');fs.symlinkSync(rust.t.package,pointer);const publicHelper=path.join(pointer,'bin/cc-msg');assert.equal(relay.resolveRelay(publicHelper).transport,'rust-v1');fs.unlinkSync(pointer);fs.symlinkSync(python.t.package,pointer);assert.equal(relay.resolveRelay(publicHelper).transport,'python-v1');
 assert.equal(relay.recordedDelivery({...result,relay:evidence},rust.binding,rust.task,rust.target,{exec:rust.inspect}),rust.wire);
 assert(rust.commands.every(c=>c.command===rust.t.relay));
 const previous=process.env.ANGELSTAR_RELAY_STORE;process.env.ANGELSTAR_RELAY_STORE=rust.t.store;
 try{assert.match(relay.inspectRelay(python.t,'status',legacy,undefined,python.inspect),/pending/);assert.equal(python.commands.at(-1).command,python.t.relay);assert.equal(python.commands.at(-1).options.env.CC_MSG_INBOX_ROOT,python.t.inbox);assert.equal(python.commands.at(-1).options.env.ANGELSTAR_RELAY_STORE,undefined);}finally{if(previous===undefined)delete process.env.ANGELSTAR_RELAY_STORE;else process.env.ANGELSTAR_RELAY_STORE=previous;}
 assert.throws(()=>relay.inspectRelay(rust.t,'recover',attempt,undefined,rust.inspect),/Read-only/);
});

test('pending exit six is retained without wire, worker promise or resend',()=>{
 const f=fixture();f.announcement.state='pending-no-input';f.announcement.submission='unproved';
 const r=ping(f.desk,'ctx1',{...f.options,send:()=>{f.sends++;return {status:6,stdout:JSON.stringify(f.announcement),stderr:''};}});
 assert.equal(r.status,6);assert.equal(r.state,'FAILED_NO_RESEND');assert.equal(r.relay.announcement.state,'pending-no-input');assert.equal(r.relay.wire,null);assert.equal(f.sends,1);assert.throws(()=>ping(f.desk,'ctx1',f.options),/EEXIST/);assert.equal(f.sends,1);
});

test('unproved pending and unsupported Rust exits are unknown, not durable pending',()=>{
 for(const status of [2,3,5,6]){
  const f=fixture();const r=ping(f.desk,'ctx1',{...f.options,send:()=>({status,stdout:'',stderr:''})});assert.equal(r.status,4);assert.equal(r.relay,null);assert.equal(r.state,'FAILED_NO_RESEND');
 }
 const f=fixture(),r=f.result();r.stdout=r.stdout.replace('"state":"submitted"','"state":"pending-no-input","state":"submitted"');assert.throws(()=>relay.deliveryEvidence(r,f.binding,f.task,f.target,{exec:f.inspect}),/duplicate/i);
});

test('legacy pre-metadata delivered records stay readable and no invented text is admitted',()=>{
 const f=fixture('python-v1'),result=f.result('Read assigned packets');
 assert.equal(relay.legacyRecordedDelivery(result,f.task,f.target),f.wire);
 const root=f.root,journalPath=path.join(root,'dispatch-journal/ctx1.jsonl');fs.mkdirSync(path.dirname(journalPath),{recursive:true});const receipt={session:'native-session',target:f.target},context={context_id:'ctx1',session_receipt:{sha256:sha('receipt')}};
 const seal={version:'net-dispatch-1',state:'SEALED',context_id:'ctx1',session:receipt.session,session_receipt_hash:context.session_receipt.sha256,task:f.task,task_hash:sha(f.task)};
 const journal=[seal,{state:'SEND_REQUESTED'},{state:'KEYSTROKES_DELIVERED',...result}];fs.writeFileSync(journalPath,journal.map(JSON.stringify).join('\n')+'\n');assert.equal(deliveredDispatch(root,context,receipt).input,f.wire);
 delete journal[2].stdout;fs.writeFileSync(journalPath,journal.map(JSON.stringify).join('\n')+'\n');assert.throws(()=>deliveredDispatch(root,context,receipt),/evidence missing/);
});

test('legacy historical pointer bytes remain verifiable without allowing new Net task spill',()=>{
 const f=fixture('python-v1'),task='#old Read assigned packets',result=f.result(task),record=JSON.parse(fs.readFileSync(f.recordPath));
 record.id=randomUUID().replaceAll('-','');record.payload=label+': #old -- full: ~/desk/tmp/relay/'+record.id.slice(0,8)+'.md';const archivePath=path.join(process.env.HOME,'desk/tmp/relay',record.id.slice(0,8)+'.md');fs.mkdirSync(path.dirname(archivePath),{recursive:true});fs.writeFileSync(archivePath,f.wire+'\n',{flag:'wx'});write(f.recordPath,record);result.stdout=`relay: ${record.id} delivered; record ${f.recordPath}\n`;
 try{assert.equal(relay.legacyRecordedDelivery(result,task,f.target,undefined,{allowPointer:true}),record.payload);assert.throws(()=>relay.legacyRecordedDelivery(result,task,f.target),/payload mismatch/);assert.throws(()=>relay.deliveryEvidence(result,f.binding,task,f.target),/task\/code mismatch/);}finally{fs.unlinkSync(archivePath);}
});

test('legacy mismatched task, source, target, payload and changed retained evidence are rejected',()=>{
 for(const mode of ['task','source','target','payload','changed']){
  const f=fixture('python-v1'),result=f.result();const evidence=relay.deliveryEvidence(result,f.binding,f.task,f.target);const record=JSON.parse(fs.readFileSync(f.recordPath));
  if(mode==='task')record.message+=' foreign';if(mode==='source')record.label='foreign';if(mode==='target')record.target.pane_pid='999';if(mode==='payload')record.payload+=' foreign';if(mode==='changed')record.foreign=true;write(f.recordPath,record);
  assert.throws(()=>relay.recordedDelivery({...result,relay:evidence},f.binding,f.task,f.target));
 }
});

test('native READY and first-task mismatches fail despite valid relay delivery evidence',()=>{
 for(const kind of ['rust-v1','python-v1']){
  const f=fixture(kind);ping(f.desk,'ctx1',f.options);f.startup(f.wire+' foreign');assert.throws(()=>attest(f.desk,'ctx1',f.options),/Operational history/);
  const g=fixture(kind).seal();dispatch(g.desk,'ctx1',{...g.options,validate:()=>({valid:true})});const d=deliveredDispatch(g.root,g.context,g.receipt,{inspect:g.inspect});fs.appendFileSync(g.recordsPath,JSON.stringify({type:'user',sessionId:'native-session',cwd:g.directory,message:{content:d.input+' foreign'}})+'\n');assert.throws(()=>checkSession(g.receipt,g.context,{target:()=>g.target,dispatch:d}),/recorded dispatch/);
 }
});

test('installed metadata, inherited environment and inline capacity fail before sending',()=>{
 const f=fixture();assert.equal(relay.resolveRelay(f.t.send).package,f.t.package);
 assert.throws(()=>relay.relayEnvironment(f.t,{ANGELSTAR_RELAY_STORE:'/wrong'}),/environment mismatch/);assert.throws(()=>relay.relayEnvironment(f.t,{TMUX:'/wrong,1,0'}),/socket mismatch/);
 const width=(label+': #r000000000000 '+shortTask).length+10;assertInlineRelay(width,label);assert.throws(()=>assertInlineRelay(width-1,label),/spill/);
 write(path.join(f.t.package,'transport.json'),{...f.t,store:'/changed'});assert.throws(()=>relay.validateTransport(f.t),/metadata changed/);
});

test('Rust inline margins four and nine refuse before send, ten fits; Python four fits',()=>{
 for(const kind of ['rust-v1','python-v1'])for(const margin of [4,9,10]){
  const f=fixture(kind).seal(),width=f.render(shortTask).length+margin,options={...f.options,validate:()=>({valid:true}),geometry:()=>({width,label})};
  if(kind==='rust-v1'&&margin<10){assert.throws(()=>dispatch(f.desk,'ctx1',options),/spill/);assert.equal(f.sends,1);assert(!fs.existsSync(path.join(f.directory,'TASK.md')));}
  else{assert.equal(dispatch(f.desk,'ctx1',options).status,0);assert.equal(f.sends,2);}
 }
 const legacyWidth=(label+': #000000 '+shortTask).length+4;assertInlineRelay(legacyWidth,label,shortTask,'python-v1');assert.throws(()=>assertInlineRelay(legacyWidth-1,label,shortTask,'python-v1'),/spill/);
});

test('target observations use the recorded socket explicitly',()=>{
 const calls=[],exec=relay.socketExec('/recorded/socket',(command,args,options)=>{calls.push({command,args,options});return {status:0,stdout:''};});exec('tmux',['list-panes'],{encoding:'utf8'});exec('ps',['-axo','pid=,ppid=']);assert.deepEqual(calls[0].args,['-S','/recorded/socket','list-panes']);assert.deepEqual(calls[1].args,['-axo','pid=,ppid=']);assert.equal(calls[0].options.timeout,5000);
});

test('independent peer observation binds names, IDs, PID, socket and kernel generations',async()=>{
 const f=fixture(),socket=path.join(f.desk,'socket'),server=net.createServer();await new Promise(resolve=>server.listen(socket,resolve));
 const t={...f.t,socket};write(path.join(t.package,'transport.json'),t);let calls=0;
 const exec=(command,args)=>{calls++;return command==='/opt/homebrew/bin/tmux'?{status:0,stdout:'net\trh-ctx1\t$3\t@4\t%7\t123\t999\n'}:{status:0,stdout:'[123000001,456000002]'};};
  try{const observed=relay.observePeer(f.target,t,exec);const stat=fs.lstatSync(socket);assert.deepEqual(observed,{...peer,socket_device:stat.dev,socket_inode:stat.ino});assert.equal(calls,2);assert.throws(()=>relay.observePeer({...f.target,pane_pid:'wrong'},t,exec),/target changed/);const own={...f.target,pane_pid:String(process.pid)},real=relay.observePeer(own,t,(command,args,options)=>command==='/opt/homebrew/bin/tmux'?{status:0,stdout:`net\trh-ctx1\t$3\t@4\t%7\t${process.pid}\t${process.pid}\n`}:spawnSync(command,args,options));assert.equal(real.server_generation,real.pane_generation);assert(real.server_generation>0);}finally{await new Promise(resolve=>server.close(resolve));}
});

test.after(()=>{for(const root of roots)fs.rmSync(root,{recursive:true,force:true});});
