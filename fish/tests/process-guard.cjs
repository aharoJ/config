// path: ~/.config/fish/tests/process-guard.cjs
// description: Prove BSD option ordering and unchanged argv without sending signals.
// patched: Substitute only the final exec with a harmless argv recorder.
// date: 2026-10-17
const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const assert = require('assert/strict');

const root = path.resolve(process.argv[2]);
fs.mkdirSync(root, { recursive: true, mode: 0o700 });
const source = fs.readFileSync(path.join(__dirname, '../internal/process/bsd-process-guard.sh'), 'utf8');
const original = 'exec "/usr/bin/$tool" "$@"';
assert.equal(source.split(original).length, 2);
const recorder = path.join(root, 'recorder.cjs');
fs.writeFileSync(recorder, 'require("fs").writeFileSync(process.env.GUARD_RECORD, JSON.stringify(process.argv.slice(2)));\n');
const shellQuote = value => "'" + value.replaceAll("'", "'\\''") + "'";
const fixture = source.replace(original, `exec ${shellQuote(process.execPath)} ${shellQuote(recorder)} "$tool" "$@"`);
const rows = [];
for (const tool of ['pkill', 'pgrep']) {
    const executable = path.join(root, tool);
    fs.writeFileSync(executable, fixture, { mode: 0o700 });
    const refusals = [
        ['-f', '^sleep 1800$', '-n'],
        ['pattern', '-n'],
        ['pattern', '-l'],
        ['-f', 'first', 'second', '-n'],
        ['--', '-first-pattern', '-n'],
        ['-P', '123', 'pattern', '-l'],
        ['-fnP123', 'pattern', '-n'],
        ...(tool === 'pkill' ? [['-int', 'pattern', '-n'], ['-SiGtStP', 'pattern', '-l']] : []),
    ];
    const passthrough = [
        [], ['pattern'], ['first', 'second'], ['-n', '-f', 'pattern'],
        ['-fln', 'pattern'], ['--', '-first-pattern'], ['-', 'second'],
        ['-t', '-', 'pattern'], ['-d', '-n', 'pattern'],
        ['-fnP123', 'pattern'], ['-fnP', '123', 'pattern'],
        ...['u', 'U', 'g', 'G', 't', 'P', 'F', 's', 'd'].map(flag => ['-' + flag, 'value', 'pattern']),
        ...['u', 'U', 'g', 'G', 't', 'P', 'F', 's', 'd'].map(flag => ['-' + flag + 'value', 'pattern']),
        ...(tool === 'pkill' ? [['-TERM', '-n', '-f', 'pattern'], ['-SIGUSR1', '-P', '123', 'pattern'], ['-0', '-f', 'pattern'], ['-int', 'pattern'], ['-SiGtStP', 'pattern']] : []),
    ];
    for (const [expect, cases] of [[2, refusals], [0, passthrough]]) {
        for (const args of cases) {
            const record = path.join(root, 'record-' + rows.length + '.json');
            const result = cp.spawnSync(executable, args, { encoding: 'utf8', timeout: 2000, env: { ...process.env, GUARD_RECORD: record } });
            assert.equal(result.status, expect, `${tool} ${JSON.stringify(args)}: ${result.stderr}`);
            if (expect === 2) {
                assert.equal(fs.existsSync(record), false);
                assert.match(result.stderr, /misplaced option .* after pattern; put all options/);
                assert.equal(result.stderr.trim().split('\n').length, 1);
            } else {
                assert.deepEqual(JSON.parse(fs.readFileSync(record, 'utf8')), [tool, ...args]);
            }
            rows.push({ tool, args, status: result.status, exec: expect === 0 });
        }
    }
}
fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ status: 'PASS', cases: rows.length, rows }, null, 2) + '\n');
console.log(`${rows.length} option-order/argv cases passed; no signal backend invoked`);
