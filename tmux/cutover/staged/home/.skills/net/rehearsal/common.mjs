import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import canonicalize from '../validator/node_modules/canonicalize/lib/canonicalize.js';
import duplicateKeys from '../validator/node_modules/json-dup-key-validator/index.js';
export const sha = b => createHash('sha256').update(b).digest('hex');
export const hash = o => sha(canonicalize(o));
export const parse = s => duplicateKeys.parse(s, false);
export const read = p => parse(fs.readFileSync(p, 'utf8'));
export const fileHash = p => sha(fs.readFileSync(p));
export const write = (p, o) => fs.writeFileSync(p, JSON.stringify(o, null, 2) + '\n');
export const inside = (root, name) => {
 const target = path.resolve(root, name);
 if (!target.startsWith(path.resolve(root) + path.sep)) throw Error('Path outside packet');
 if (!fs.realpathSync(target).startsWith(fs.realpathSync(root) + path.sep)) throw Error('Symlink outside packet');
 return target;
};
