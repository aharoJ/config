const cwd = process.argv[3];
let state = process.argv[2] || 'fresh', buf = '';
const out = s => process.stdout.write(s);
let used = state === 'used'; if (used) state = 'fresh';
const footer = () => `  Fast off · GPT-6.1-Sol low · ${cwd} · Context ${used ? 12 : 0}% used`;
const HL = '\x1b[1;7m';
function draw() {
  out('\x1b[2J\x1b[H');
  let rows, cur;
  if (state === 'fresh' || state === 'slash') {
    rows = ['', '  >_ OpenAI Codex (v0.160.0)', '     ' + cwd, '  permissions: YOLO mode', '', '  Bring a question.', '', '  Tip: Use /title.', '', ''];
    if (used) rows.push('• earlier reply', '');
    if (state === 'slash') {
      rows.push(HL + '› /new  start a new chat during a conversation\x1b[0m', '', '› /new');
    } else rows.push('\x1b[1m›\x1b[0m \x1b[2mAsk Codex to do anything\x1b[0m');
    cur = [state === 'slash' ? 6 : 2, rows.length - 1];
    rows.push('', footer());
  } else {
    rows = ['', '  Where should the new conversation run?', '', HL + '› 1. Current checkout  Keep using the current working directory\x1b[0m', '  2. New worktree      Create an isolated managed checkout', '', '  enter select · esc back'];
    cur = [0, 0];
  }
  out(rows.join('\r\n'));
  out(`\x1b[${cur[1] + 1};${cur[0] + 1}H`);
}
process.stdin.setRawMode(true);
process.stdin.on('data', d => {
  let s = d.toString().replace(/\x1b\[20[01]~/g, '');
  for (const ch of s) {
    if (ch === '\r') {
      if (state === 'slash') state = 'menu';
      else if (state === 'menu') { state = 'fresh'; used = false; }
      buf = '';
    } else if (ch === '2' && state === 'menu') { state = 'worktree'; }
    else if (state === 'fresh' || state === 'slash') { buf += ch; if (buf === '/new') state = 'slash'; }
  }
  draw();
});
draw();
