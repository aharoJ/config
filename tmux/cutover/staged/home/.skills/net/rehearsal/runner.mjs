#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import Ajv from '../validator/node_modules/ajv/dist/2020.js';
import formats from '../validator/node_modules/ajv-formats/dist/index.js';
import {fileURLToPath} from 'node:url';
import {read,sha,hash,fileHash} from './common.mjs';
import {validatePreparation} from './prerequisites.mjs';
import {checkSession,observeTarget} from './session.mjs';
import {resolveRelay,bindRelay,observePeer,sourceGeometry,relayEnvironment,deliveryEvidence,socketExec} from './relay.mjs';
export const shortTask='Read TASK.md in this folder and execute it.';
export const frozenTask=directory=>`Read ${directory}/PROMPT.md and only the assigned packets in ${directory}/packets. Write first answer bytes only into ${directory}/out/answer-CASE_ID.json using exclusive creation (never overwrite). No network retrieval. Preserve existing files. Follow the frozen phase1 schema.`;
export function assertInlineRelay(width,label,message=shortTask,kind='rust-v1'){
 const code=kind==='rust-v1'?'r000000000000':'000000',margin=kind==='rust-v1'?10:4;
 if(!Number.isInteger(width)||width<1||typeof label!=='string'||!label||!/^[\x20-\x7e]+$/.test(label+message)||(label+': #'+code+' '+message).length>width-margin)throw Error('Relay would spill to an inaccessible pointer');
 return true;
}
export const relayGeometry=sourceGeometry;
export function dispatch(desk,contextId,{validate=validatePreparation,target=observeTarget,send=spawnSync,geometry=relayGeometry,transport=resolveRelay,peer=observePeer,inspect=spawnSync}={}){
 const checked=validate(desk);if(!checked.valid)throw Error('Prerequisites invalid');
 const prep=read(path.join(desk,'run-preparation','PREPARATION.json')),context=prep.contexts.find(c=>c.context_id===contextId);
 if(!context||!/^[a-zA-Z0-9_-]+$/.test(contextId)||!context.session_receipt)throw Error('Exact attested context required');
 const receipt=read(context.session_receipt.path);
 if(fileHash(context.session_receipt.path)!==context.session_receipt.sha256)throw Error('Changed session receipt');
 if(receipt.tmux_session!=='net'||receipt.tmux_window!==`rh-ctx${prep.contexts.indexOf(context)+1}`)throw Error('Wrong exact target');
 const terminal=new Set(prep.terminal_dispositions.map(t=>t.case_id));if(context.dispatch_case_ids.some(id=>terminal.has(id)))throw Error('Terminal assignment cannot dispatch');
 const journals=path.join(desk,'run-preparation','dispatch-journal');fs.mkdirSync(journals,{recursive:true});
 const journalPath=path.join(journals,contextId+'.jsonl');
 const fd=fs.openSync(journalPath,'wx',0o600);
 const ajv=new Ajv({strict:false});formats(ajv);const validEvent=ajv.compile(read(new URL('./DISPATCH.schema.json',import.meta.url)));
 const append=r=>{if(!validEvent(r))throw Error('Invalid lifecycle journal record');fs.writeSync(fd,JSON.stringify(r)+'\n');fs.fsyncSync(fd);};
 try{
  const manifest=read(path.join(desk,'run-preparation','RUN-MANIFEST.json')).manifest;
  const selected=transport(),environment=relayEnvironment(selected),boundTarget=(s,w)=>target(s,w,socketExec(selected.socket));
  checkSession(receipt,context,{target:boundTarget});
  const {width,label}=geometry(receipt,socketExec(selected.socket)),relay_binding=bindRelay(receipt.target,label,selected,peer);assertInlineRelay(width,label,shortTask,selected.transport);
  const task=shortTask,taskFile=path.join(context.directory,'TASK.md'),content=frozenTask(context.directory)+'\n';
  fs.writeFileSync(taskFile,content,{flag:'wx',mode:0o600});
  const taskFileHash=fileHash(taskFile);
  const sealed={version:'net-dispatch-1',state:'SEALED',context_id:contextId,session:receipt.session,session_receipt_hash:context.session_receipt.sha256,preparation_hash:fileHash(path.join(desk,'run-preparation','PREPARATION.json')),task_hash:sha(task),task,task_file:taskFile,task_file_hash:taskFileHash,relay_width:width,relay_label:label,relay_binding,at:new Date().toISOString(),attempts:context.dispatch_case_ids.map(id=>{const p=manifest.cases.find(p=>p.case_id===id);if(!p)throw Error('Missing frozen attempt');return {case_id:id,attempt_id:p.attempt_id,packet_hash:p.packet_hash};})};
  append(sealed);
  const inputs=path.join(desk,'run-preparation','input-receipts');fs.mkdirSync(inputs,{recursive:true});
  for(const a of sealed.attempts){if(!/^[a-zA-Z0-9_-]+$/.test(a.attempt_id))throw Error('Unsafe attempt ID');fs.writeFileSync(path.join(inputs,a.attempt_id+'.json'),JSON.stringify({...a,session:receipt.session,session_receipt_hash:context.session_receipt.sha256,dispatch_seal_hash:hash(sealed),at:sealed.at})+'\n',{flag:'wx'});}
  if(fileHash(taskFile)!==taskFileHash)throw Error('Staged task changed');
  const finalGeometry=geometry(receipt,socketExec(selected.socket));if(finalGeometry.label!==label)throw Error('Relay source changed');assertInlineRelay(finalGeometry.width,label,shortTask,selected.transport);
  append({state:'SEND_REQUESTED',at:new Date().toISOString()});
  const result=send(selected.send,[task],{env:{...environment,CC_MSG_SESSION:'net',CC_MSG_WINDOW:receipt.tmux_window,CLAUDE_CONFIG_DIR:receipt.configuration_directory},encoding:'utf8'});
  let status=result.status??4,relay=null,error=result.error?.message??null;
  try{relay=deliveryEvidence(result,relay_binding,task,receipt.target,{exec:inspect});if(hash(boundTarget(receipt.tmux_session,receipt.tmux_window))!==hash(receipt.target))throw Error('Dispatch target changed during delivery');}catch(e){if(status===0||selected.transport==='rust-v1'&&status!==1&&status!==4)status=4;error=e.message;}
  const state=status===0?'KEYSTROKES_DELIVERED':status===1?'ROUTING_REFUSED':selected.transport==='python-v1'&&status===2?'COPY_MODE_REFUSED':selected.transport==='python-v1'&&status===5?'DRAFT_REFUSED':'DELIVERY_UNKNOWN';
  append({state,status,stdout:result.stdout??'',stderr:result.stderr??'',error,relay,at:new Date().toISOString()});
  return {context_id:contextId,state,status,journal_path:journalPath};
 }catch(e){append({state:'FAILED_NO_RESEND',error:e.message,at:new Date().toISOString()});throw e;}finally{fs.closeSync(fd);}
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))try{const r=dispatch(...process.argv.slice(2));console.log(JSON.stringify(r));process.exitCode=r.status;}catch(e){console.error('REFUSED: '+e.message);process.exitCode=2;}
