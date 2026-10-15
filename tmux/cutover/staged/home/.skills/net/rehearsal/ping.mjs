#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import Ajv from '../validator/node_modules/ajv/dist/2020.js';
import formats from '../validator/node_modules/ajv-formats/dist/index.js';
import {read,fileHash,hash} from './common.mjs';
import {observeTarget} from './session.mjs';
import {resolveRelay,bindRelay,observePeer,sourceGeometry,relayEnvironment,deliveryEvidence,socketExec} from './relay.mjs';
export const pingPath=(desk,id)=>path.join(desk,'run-preparation','ping-journal',id+'.jsonl');
const schema=()=>{const ajv=new Ajv({strict:false});formats(ajv);return ajv.compile(read(new URL('./PING.schema.json',import.meta.url)));};
export function checkPing(desk,launch,live){
 const events=fs.readFileSync(pingPath(desk,launch.context_id),'utf8').trim().split('\n').map(JSON.parse),check=schema();
 if(events.length!==2||events.some(e=>!check(e))||events[0].state!=='SEND_REQUESTED'||events[1].state!=='KEYSTROKES_DELIVERED'||events[1].status!==0||events.some(e=>e.context_id!==launch.context_id||e.session!==launch.session||e.tmux_session!==launch.tmux_session||e.tmux_window!==launch.tmux_window||e.bootstrap_hash!==fileHash(path.join(desk,'run-preparation','bootstrap',launch.context_id+'.json'))||hash(e.target)!==hash(live))||events[0].relay_id!==events[1].relay_id||Date.parse(events[0].at)<Date.parse(launch.started_at)||Date.parse(events[1].at)<Date.parse(events[0].at))throw Error('Neutral ping delivery evidence invalid');
 if((events[0].relay_binding||events[1].relay_binding)&&hash(events[0].relay_binding)!==hash(events[1].relay_binding))throw Error('Neutral ping relay binding changed');
 return fileHash(pingPath(desk,launch.context_id));
}
export function ping(desk,id,{target=observeTarget,send=spawnSync,transport=resolveRelay,peer=observePeer,geometry=sourceGeometry,inspect=spawnSync}={}){
 const prep=read(path.join(desk,'run-preparation','PREPARATION.json')),context=prep.contexts.find(c=>c.context_id===id);
 if(!context||!/^[a-zA-Z0-9_-]+$/.test(id))throw Error('Unknown context');
 const launch=read(path.join(desk,'run-preparation','bootstrap',id+'.json'));
 if(launch.context_id!==id||launch.tmux_session!=='net'||launch.tmux_window!==`rh-ctx${prep.contexts.indexOf(context)+1}`)throw Error('Wrong exact ping target');
 const selected=transport(),environment=relayEnvironment(selected),boundTarget=(s,w)=>target(s,w,socketExec(selected.socket));
 const live=boundTarget(launch.tmux_session,launch.tmux_window);
 if(live.process_session!==launch.session||live.requested_model!==launch.model||live.requested_effort!==launch.effort||path.resolve(live.directory)!==path.resolve(context.directory))throw Error('Ping live target mismatch');
 const {label}=geometry({tmux_session:launch.tmux_session,tmux_window:launch.tmux_window,target:live},socketExec(selected.socket)),relay_binding=bindRelay(live,label,selected,peer);
 const destination=pingPath(desk,id);fs.mkdirSync(path.dirname(destination),{recursive:true});const fd=fs.openSync(destination,'wx',0o600),check=schema();
 const base={version:'net-ping-1',relay_id:randomUUID(),context_id:id,session:launch.session,tmux_session:launch.tmux_session,tmux_window:launch.tmux_window,bootstrap_hash:fileHash(path.join(desk,'run-preparation','bootstrap',id+'.json')),target:live,message:'reply READY, read nothing',relay_binding};
 const append=e=>{const row={...base,at:new Date().toISOString(),...e};if(!check(row))throw Error('Invalid ping event');fs.writeSync(fd,JSON.stringify(row)+'\n');fs.fsyncSync(fd);return row;};
 try{
  append({state:'SEND_REQUESTED',status:null,stdout:'',stderr:''});
  let result;
  try{result=send(selected.send,[base.message],{env:{...environment,CC_MSG_SESSION:'net',CC_MSG_WINDOW:launch.tmux_window},encoding:'utf8'});}catch(e){append({state:'FAILED_NO_RESEND',status:null,stdout:'',stderr:e.message});throw e;}
  let status=result.status??null,relay=null,stderr=result.stderr??'';
  try{relay=deliveryEvidence(result,relay_binding,base.message,live,{exec:inspect});if(hash(boundTarget(launch.tmux_session,launch.tmux_window))!==hash(live))throw Error('Ping target changed during delivery');}catch(e){if(status===0||selected.transport==='rust-v1'&&status!==1&&status!==4)status=4;stderr+=(stderr?'\n':'')+e.message;}
  return append({state:status===0?'KEYSTROKES_DELIVERED':'FAILED_NO_RESEND',status,stdout:result.stdout??'',stderr,relay});
 }finally{fs.closeSync(fd);}
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))try{const result=ping(...process.argv.slice(2));console.log(JSON.stringify(result));process.exitCode=result.status===0?0:2;}catch(e){console.error(e.message);process.exitCode=2;}
