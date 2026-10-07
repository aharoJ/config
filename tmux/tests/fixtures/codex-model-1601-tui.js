const fs = require('fs');
const [,, cwd, log, scenario = 'model'] = process.argv;
const models = [
  ['GPT-6.1-Sol', 'Latest workhorse model for coding and everyday work.'],
  ['GPT-6-Astra', 'Frontier intelligence for the most demanding work.'],
  ['GPT-6-Sol', 'Previous generation workhorse model.'],
  ['GPT-6-Luna', 'Fast and affordable model for easier tasks.'],
  ['GPT-5.6-Sol', 'Older generation workhorse model.'],
  ['GPT-5.6-Terra', 'Older balanced model for straightforward work.'],
  ['GPT-5.6-Luna', 'Older fast and efficient model.'],
];
const levels = [
  ['Low', 'Fast responses with lighter reasoning'],
  ['Medium', 'Balances speed and reasoning depth for everyday tasks'],
  ['High', 'Greater reasoning depth for complex problems'],
  ['Extra high', 'Extra high reasoning depth for complex problems'],
  ['More reasoning…', 'Max and Ultra consume usage limits faster'],
];
const advanced = [['Max', 'For difficult problems when quality matters more than speed · higher usage'], ['Ultra', 'For demanding work using multiple agents · highest usage']];
let state = 'fresh', model = 'GPT-5.6-Terra', effort = 'max', selected = 5, command = '', notice = '';
let used = scenario === 'reset', draft = scenario === 'draft' ? 'owned draft' : '';
const hl = '\x1b[1;7m';
function draw() {
  const rows = ['', '  \x1b[38;2;99;168;248m>_ \x1b[1m\x1b[39mOpenAI Codex\x1b[0;2m (v0.160.1)\x1b[0m', '     \x1b[2m' + cwd + '\x1b[0m', '  permissions: YOLO mode', '', '  Bring a question.', '', '  Tip: Use /title.', '', ''];
  let cursor = [0, 0];
  if (state === 'fresh' || state === 'slash') {
    if (used) rows.push('• earlier reply', '');
    if (notice) rows.push(notice, '');
    if (state === 'slash') rows.push(hl + '› ' + command + '  ' + (command === '/model' ? 'choose what model and reasoning effort to use' : 'start a new chat during a conversation') + '\x1b[0m', '', '› ' + command);
    else rows.push('\x1b[1m›\x1b[0m ' + (draft || '\x1b[2mAsk Codex to do anything\x1b[0m'));
    cursor = [state === 'slash' ? command.length + 2 : draft.length + 2, rows.length - 1];
    rows.push('', '  \x1b[38;2;135;140;164mFast off · ' + model + ' ' + effort + ' · ' + cwd + ' · Context ' + (used ? 12 : 0) + '% used\x1b[39m');
  } else {
    let choices, title, hint;
    if (state === 'models') { choices = models; title = 'Select Model and Effort'; hint = 'enter select · esc back'; }
    else if (state === 'efforts') { choices = levels; title = 'Select Reasoning Level for ' + model; hint = selected === 4 ? 'enter select · esc back' : 'enter default · s session · esc back'; }
    else if (state === 'advanced') { choices = advanced; title = 'Advanced Reasoning'; hint = 'enter default · s session · esc back'; }
    else { choices = [['Current checkout', 'Keep using the current working directory'], ['New worktree', 'Create an isolated managed checkout']]; title = 'Where should the new conversation run?'; hint = 'enter select · esc back'; }
    rows.push('  \x1b[1m' + title + '\x1b[0m', '');
    if (state === 'advanced') rows.push('  ⚠ Consumes usage limits faster', '');
    choices.forEach(([label, description], index) => {
      if (state === 'models' && label === model) label += ' (current)';
      if (state === 'efforts' && index === 0) label += ' (default) (current)';
      rows.push((index === selected ? hl + '› ' : '\x1b[0m  ') + (index + 1) + '. ' + label + (state === 'menu' && index === 1 ? '      ' : '  ') + (index === selected ? '\x1b[0;7m' : '\x1b[2m') + description + '\x1b[0m');
    });
    rows.push('', '  ' + hint);
  }
  process.stdout.write('\x1b[2J\x1b[H' + rows.join('\r\n') + `\x1b[${cursor[1] + 1};${cursor[0] + 1}H`);
}
process.stdin.setRawMode(true);
process.stdin.on('data', data => {
  fs.appendFileSync(log, JSON.stringify(data.toString()) + '\n');
  const text = data.toString().replace(/\x1b\[20[01]~/g, '');
  if (text === '\x1b[A' || text === '\x1b[B') selected += text === '\x1b[A' ? -1 : 1;
  else for (const ch of text) {
    if (ch === '\r') {
      if (state === 'slash') { state = command === '/new' ? 'menu' : 'models'; selected = state === 'menu' ? 0 : models.findIndex(x => x[0] === model); }
      else if (state === 'menu') { state = 'fresh'; used = false; model = 'GPT-6.1-Sol'; effort = 'low'; }
      else if (state === 'models') { model = models[selected][0]; state = 'efforts'; selected = 0; }
      else if (state === 'efforts' && selected === 4) { state = 'advanced'; selected = 0; }
      command = '';
    } else if (state === 'models' && /^[1-7]$/.test(ch)) { model = models[Number(ch) - 1][0]; state = 'efforts'; selected = 0; }
    else if (state === 'efforts' && ch === '5') { state = 'advanced'; selected = 0; }
    else if ((state === 'efforts' || state === 'advanced') && ch === 's') {
      effort = state === 'advanced' ? ['max', 'ultra'][selected] : ['low', 'medium', 'high', 'xhigh'][selected];
      notice = '• Model changed to ' + model.toLowerCase() + ' ' + effort + ' for this session only'; state = 'fresh';
    } else if (state === 'fresh') { command += ch; if (command === '/new' || command === '/model') state = 'slash'; }
  }
  draw();
});
draw();
