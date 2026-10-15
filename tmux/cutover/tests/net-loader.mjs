import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

const staged=fileURLToPath(new URL('home/.skills/net/',new URL('../staged/',import.meta.url)));
const original=path.join(process.env.HOME,'.skills/net/');
export async function resolve(specifier,context,nextResolve){
 if(specifier.startsWith('.')&&context.parentURL?.startsWith('file:')){
  const target=fileURLToPath(new URL(specifier,context.parentURL));
  const prefix=[staged,original].find(p=>target.startsWith(p));
  if(prefix){const relative=target.slice(prefix.length),candidate=path.join(staged,relative),fallback=path.join(original,relative);return nextResolve(pathToFileURL(fs.existsSync(candidate)?candidate:fallback).href,context);}
 }
 return nextResolve(specifier,context);
}
