#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import Ajv from '../validator/node_modules/ajv/dist/2020.js';
import formats from '../validator/node_modules/ajv-formats/dist/index.js';
import {read,hash,sha,fileHash} from './common.mjs';
import {checkPing,pingPath} from './ping.mjs';
import {observeTarget,inventory,records,receiptPath} from './session.mjs';
import {recordedDelivery,legacyRecordedDelivery} from './relay.mjs';
export function attest(desk,id,{target=observeTarget,inspect=spawnSync}={}){
 const prep=read(path.join(desk,'run-preparation','PREPARATION.json')),context=prep.contexts.find(c=>c.context_id===id);
 if(!context)throw Error('Unknown context');
 const launch=read(path.join(desk,'run-preparation','bootstrap',id+'.json'));
 const ajv=new Ajv({strict:false});formats(ajv);
 if(!ajv.compile(read(new URL('./BOOTSTRAP.schema.json',import.meta.url)))(launch))throw Error('Bootstrap schema invalid');
 const approval=read(path.join(desk,'CONFIGURATION-APPROVAL.json')),cfg=read(path.join(desk,'RECEIPT-C.json'));
 if(approval.status!=='VERIFIED'||approval.configuration_receipt_hash!==fileHash(path.join(desk,'RECEIPT-C.json'))||fileHash(approval.authority_path)!==approval.authorization_hash)throw Error('Recorded approval custody mismatch');
 if(launch.context_id!==id || launch.directory!==context.directory || launch.model!==cfg.candidate.effective_model || launch.effort!=='medium' || launch.no_resume!==true || launch.no_prompt!==true || launch.tmux_window!==`rh-ctx${prep.contexts.indexOf(context)+1}` || launch.tmux_session!=='net')throw Error('Bootstrap tuple mismatch');
 const live=target(launch.tmux_session,launch.tmux_window);
 if(live.process_session!==launch.session || live.requested_model!==launch.model || live.requested_effort!==launch.effort || path.resolve(live.directory)!==path.resolve(context.directory))throw Error('Target directory mismatch');
 const ping_hash=checkPing(desk,launch,live);
 const delivery=fs.readFileSync(pingPath(desk,id),'utf8').trim().split('\n').map(JSON.parse)[1];
 const bytes=fs.readFileSync(launch.records_path);
 const expected=delivery.relay_binding?recordedDelivery(delivery,delivery.relay_binding,'reply READY, read nothing',live,{exec:inspect}):legacyRecordedDelivery(delivery,'reply READY, read nothing',live);
 records(bytes,launch.session,context.directory,{neutralMessage:expected});
 if(fileHash(launch.profile_path)!==launch.profile_hash || inventory(context.directory)!==launch.inventory_hash || !Number.isFinite(Date.parse(launch.started_at)))throw Error('Startup inventory/chronology mismatch');
 const receipt={ping_hash,version:'net-session-1',context_id:id,session:launch.session,model:launch.model,requested_effort:launch.effort,effective_effort:'UNOBSERVABLE',billing_mode:cfg.candidate.billing_mode,account_or_seat:cfg.candidate.account_or_seat,configuration_directory:launch.configuration_directory,directory:context.directory,tmux_session:launch.tmux_session,tmux_window:launch.tmux_window,target:live,approval_hash:fileHash(path.join(desk,'CONFIGURATION-APPROVAL.json')),authority_hash:approval.authorization_hash,bootstrap_hash:fileHash(path.join(desk,'run-preparation','bootstrap',id+'.json')),inventory_hash:launch.inventory_hash,records_path:launch.records_path,records_hash:sha(bytes),records_length:bytes.length,started_at:launch.started_at,attested_at:new Date().toISOString(),no_resume:true,no_operational_exposure:true,network_denial_proven:false};
 if(!ajv.compile(read(new URL('./SESSION-RECEIPT.schema.json',import.meta.url)))(receipt))throw Error('Session receipt schema invalid');
 if(Date.parse(receipt.started_at)>Date.parse(receipt.attested_at))throw Error('Future startup');
 const destination=receiptPath(desk,id);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});return {context_id:id,receipt_path:destination,receipt_hash:fileHash(destination)};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))try{console.log(JSON.stringify(attest(...process.argv.slice(2))));}catch(e){console.error(e.message);process.exitCode=2;}
