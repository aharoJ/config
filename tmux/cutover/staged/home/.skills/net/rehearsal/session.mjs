import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {read,hash,sha,fileHash} from './common.mjs';
import {recordedDelivery,legacyRecordedDelivery} from './relay.mjs';
export const neutral='codex: reply READY, read nothing';
export function inventory(directory,{omitTask=false}={}){
 if(!fs.lstatSync(path.resolve(directory)).isDirectory()||path.basename(path.resolve(directory)).toLowerCase()==='.git')throw Error('Session directory must be a real packet directory');
 const files=[];
 const walk=(dir,capture=true)=>{for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.name.toLowerCase()==='.git')throw Error('Git metadata in session packet; stage approved file copies in an isolated seat');if(e.isSymbolicLink())throw Error('Session directory symlink');if(e.isDirectory())walk(p,capture&&p!==path.join(directory,'out'));else if(capture&&!(omitTask&&p===path.join(directory,'TASK.md')))files.push({path:path.relative(directory,p),sha256:fileHash(p)});}};
 walk(directory);return hash(files.sort((a,b)=>a.path.localeCompare(b.path)));
}
export function observeTarget(session,window,exec=spawnSync){
 if(session!=='net'||!/^rh-ctx[0-9]+$/.test(window))throw Error('Invalid exact target');
 const result=exec('tmux',['list-panes','-a','-F','#{session_name}\t#{window_name}\t#{pane_id}\t#{pane_pid}\t#{pane_current_command}\t#{pane_current_path}'],{encoding:'utf8'});
 if(result.status!==0)throw Error('Cannot observe visible target');
 const rows=result.stdout.trim().split('\n').map(x=>x.split('\t')).filter(x=>x[0]===session&&x[1]===window);
 if(rows.length!==1)throw Error('Target is not one visible Claude pane');
 const ps=exec('ps',['-ax','-o','pid=,ppid=,command='],{encoding:'utf8'});if(ps.status!==0)throw Error('Cannot verify live session process');
 const processes=ps.stdout.split('\n').map(line=>line.trim().match(/^(\d+)\s+(\d+)\s+(.+)$/)).filter(Boolean),descendants=new Set([rows[0][3]]);
 for(let changed=true;changed;){changed=false;for(const p of processes)if(descendants.has(p[2])&&!descendants.has(p[1])){descendants.add(p[1]);changed=true;}}
 const matches=processes.filter(p=>descendants.has(p[1])&&/(?:^|\s)(?:\S*\/)?claude(?:\s|$)/.test(p[3])&&/--session-id\s/.test(p[3]));
 if(matches.length!==1)throw Error('Live checker session process ambiguous or absent');
 const cmd=matches[0][3],argument=name=>cmd.match(new RegExp('(?:^| )--'+name+' +([^ ]+)'))?.[1];
 if(/(?:^|\s)(?:--(?:print|background|bg)(?:[=\s]|$)|-(?!-)\S*p\S*(?:\s|$))/.test(cmd))throw Error('Headless Claude process refused; identify a visible interactive pane without print/background flags');
 return {tmux_session:session,tmux_window:window,pane_id:rows[0][2],pane_pid:rows[0][3],command:rows[0][4],directory:rows[0][5],process_pid:matches[0][1],process_session:argument('session-id')??'',requested_model:argument('model')??'',requested_effort:argument('effort')??''};
}
export function records(bytes,session,directory,{beforeDispatch=true,neutralMessage=neutral}={}){
 const rows=bytes.toString('utf8').trim().split('\n').filter(Boolean).map(s=>JSON.parse(s));
 if(!rows.length || rows.some(r=>r.sessionId&&r.sessionId!==session))throw Error('Session records identity mismatch');
 const users=rows.filter(r=>r.type==='user');
 if(rows.some(r=>r.isSidechain || r.type==='system'&&/resume|compact/i.test(r.subtype??'')) || users.some(r=>r.cwd&&path.resolve(r.cwd)!==path.resolve(directory)))throw Error('Resumed or foreign session history');
 if(beforeDispatch && (users.length!==1||users.some(r=>r.message?.content!==neutralMessage)))throw Error('Operational history before attestation');
 if(beforeDispatch && rows.some(r=>r.message?.content?.some?.(c=>c.type==='tool_use')))throw Error('Tools used during neutral startup');
 if(beforeDispatch){
  let ready=false;
  const pingIndex=rows.indexOf(users[0]);
  for(const [index,row] of rows.entries()){
   if(row.type!=='assistant')continue;
   const content=row.message?.content;
   if(index<pingIndex || ready || !Array.isArray(content) || content.length===0)throw Error('Neutral READY reply absent or extra assistant record');
   if(content.every(block=>block.type==='thinking'))continue;
   if(content.length!==1 || content[0].type!=='text' || content[0].text!=='READY')throw Error('Neutral READY reply absent or extra assistant content');
   ready=true;
  }
  if(!ready)throw Error('Neutral READY reply absent');
 }
 const models=new Set(rows.map(r=>r.message?.model??r.attachment?.identity?.modelId).filter(Boolean));
 if(models.size!==1 || !models.has('claude-opus-5-5'))throw Error('Unknown or mismatched effective model');
 return rows;
}
export function deliveredDispatch(root,context,receipt,{inspect=spawnSync}={}){
 const journalPath=path.join(root,'dispatch-journal',context.context_id+'.jsonl');
 if(!fs.existsSync(journalPath))return null;
 const journal=fs.readFileSync(journalPath,'utf8').trim().split('\n').map(JSON.parse);
 if(journal.at(-1)?.state!=='KEYSTROKES_DELIVERED')return null;
 const [sealed,requested,delivery]=journal;
 if(journal.length!==3 || sealed.state!=='SEALED' || sealed.version!=='net-dispatch-1' || requested.state!=='SEND_REQUESTED' || delivery.status!==0 || sealed.context_id!==context.context_id || sealed.session!==receipt.session || sealed.session_receipt_hash!==context.session_receipt.sha256 || typeof sealed.task!=='string' || sha(sealed.task)!==sealed.task_hash)throw Error('Invalid delivered dispatch binding');
 if(sealed.task_file!==undefined&&(sealed.task_file!==path.join(context.directory,'TASK.md')||fileHash(sealed.task_file)!==sealed.task_file_hash))throw Error('Staged task file changed');
 const input=sealed.relay_binding?recordedDelivery(delivery,sealed.relay_binding,sealed.task,receipt.target,{exec:inspect}):legacyRecordedDelivery(delivery,sealed.task,receipt.target,sealed.relay_label,{allowPointer:sealed.task_file===undefined});
 return {input,task_file:sealed.task_file,task_file_hash:sealed.task_file_hash};
}
export function checkSession(receipt,context,{target=observeTarget,beforeDispatch=true,dispatch=null}={}){
 if(receipt.context_id!==context.context_id || receipt.directory!==context.directory || receipt.session!==context.access_receipt.session || receipt.configuration_directory!==context.access_receipt.configuration_directory || inventory(context.directory,{omitTask:dispatch?.task_file===path.join(context.directory,'TASK.md')})!==receipt.inventory_hash)throw Error('Session context/inventory mismatch');
 const current=target(receipt.tmux_session,receipt.tmux_window);
 if(current.process_session!==receipt.session || current.requested_model!==receipt.model || current.requested_effort!==receipt.requested_effort || hash(current)!==hash(receipt.target))throw Error('Live pane identity changed');
 const bytes=fs.readFileSync(receipt.records_path);
 if(bytes.length<receipt.records_length || sha(bytes.subarray(0,receipt.records_length))!==receipt.records_hash)throw Error('Session transcript prefix changed');
 const sealedUser=bytes.subarray(0,receipt.records_length).toString('utf8').trim().split('\n').map(JSON.parse).find(r=>r.type==='user')?.message?.content;
 if(dispatch){
  records(bytes.subarray(0,receipt.records_length),receipt.session,context.directory,{neutralMessage:sealedUser});
  records(bytes,receipt.session,context.directory,{beforeDispatch:false});
  const tail=bytes.subarray(receipt.records_length).toString('utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
  const messages=tail.filter(r=>r.type==='user'||r.type==='assistant');
  if(messages[0]?.type!=='user' || messages[0].message?.content!==dispatch.input || messages.filter(r=>r.type==='user'&&typeof r.message?.content==='string').length!==1)throw Error('Post-prefix history does not begin with recorded dispatch task');
 }else records(bytes,receipt.session,context.directory,{beforeDispatch,neutralMessage:sealedUser});
 return current;
}
export function receiptPath(desk,id){return path.join(desk,'run-preparation','session-receipts',`SESSION-RECEIPT-${id}.json`);}
export function exactMappings(contexts,entries){
 const sessions=new Set(),ids=new Set();
 for(const c of contexts){
  if(ids.has(c.context_id)||!c.session_receipt)throw Error('Missing or duplicate context receipt');ids.add(c.context_id);
  const r=read(c.session_receipt.path);
  if(fileHash(c.session_receipt.path)!==c.session_receipt.sha256 || r.context_id!==c.context_id || r.session!==c.access_receipt.session || !r.session || sessions.has(r.session))throw Error('Changed or reused mapped session');sessions.add(r.session);
  if(entries.filter(e=>e.context_id===c.context_id&&e.session===r.session&&e.session_receipt_hash===c.session_receipt.sha256).length!==1)throw Error('Missing or ambiguous exact allowlist mapping');
 }
 return true;
}
