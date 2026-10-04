const fs = require('fs');
const [, , start = 'fresh', cwd, log] = process.argv;
let state = start, used = false, draft = '', buf = '';
if (state === 'used' || state === 'stale') { used = true; state = 'fresh'; }
if (state === 'draft') { draft = 'unsent draft'; state = 'fresh'; }
const out = s => process.stdout.write(s);
const HL = '\x1b[1;7m';
const footer = () => `  Fast off · GPT-6.1-Sol low · ${cwd} · Context ${used ? 12 : 0}% used`;
function draw() {
  out('\x1b[2J\x1b[H');
  let rows, cur;
  if (['fresh', 'slash', 'working', 'compacting'].includes(state)) {
    rows = ['', '  >_ OpenAI Codex (v0.160.0)', '     ' + cwd, '  permissions: YOLO mode', '', '  Bring a question.', '', '  Tip: Use /title.', '', ''];
    if (start === 'stale') rows.unshift(`  Fast off · GPT-6.1-Sol low · ${cwd} · Context 0% used`, '');
    if (used) rows.push('• earlier reply', '');
    if (state === 'working') rows.push('• Working (3s • esc to interrupt)', '');
    if (state === 'compacting') rows.push('• Compacting context (3s • esc to interrupt)', '');
    if (state === 'slash') rows.push(HL + '› /new  start a new chat during a conversation\x1b[0m', '', '› /new');
    else if (draft) rows.push('› ' + draft);
    else rows.push('\x1b[1m›\x1b[0m \x1b[2mAsk Codex to do anything\x1b[0m');
    cur = [state === 'slash' ? 6 : draft ? 2 + draft.length : 2, rows.length - 1];
    rows.push('', footer());
  } else if (state === 'worktree') {
    rows = ['WORKTREE CHOSEN']; cur = [0, 0];
  } else {
    const two = state === 'menu2';
    rows = ['', '  Where should the new conversation run?', '',
      (two ? '  ' : HL + '› ') + '1. Current checkout  Keep using the current working directory' + (two ? '' : '\x1b[0m'),
      (two ? HL + '› ' : '  ') + '2. New worktree      Create an isolated managed checkout' + (two ? '\x1b[0m' : ''),
      '', '  enter select · esc back'];
    cur = [0, 0];
  }
  out(rows.join('\r\n'));
  out(`\x1b[${cur[1] + 1};${cur[0] + 1}H`);
}
process.stdin.setRawMode(true);
process.stdin.on('data', d => {
  if (log) fs.appendFileSync(log, JSON.stringify(d.toString()) + '\n');
  for (const ch of d.toString().replace(/\x1b\[20[01]~/g, '')) {
    if (ch === '\r') {
      if (state === 'slash') state = 'menu';
      else if (state === 'menu') { state = 'fresh'; used = false; }
      else if (state === 'menu2') { state = 'worktree'; if (log) fs.appendFileSync(log, JSON.stringify('WORKTREE') + '\n'); }
      buf = '';
    } else if (state === 'fresh') { buf += ch; if (buf === '/new') state = 'slash'; }
  }
  draw();
});
if (start === 'flip') { state = 'menu'; const flip = setInterval(() => { if (state !== 'menu' && state !== 'menu2') return clearInterval(flip); state = state === 'menu' ? 'menu2' : 'menu'; draw(); }, 37); }
draw();
