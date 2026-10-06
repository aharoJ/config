#!/usr/bin/env python3
import argparse
import codecs
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tty

ROOT = Path(__file__).resolve().parents[1]


def agy_fixture(directory):
    directory = Path(directory)
    tty.setraw(0)
    manifest = json.loads((ROOT / 'tests/fixtures/relay-must-accept.json').read_text())
    case = next(row for row in manifest['cases'] if row['name'] == 'agy-fresh')
    rows = (ROOT / 'tests/fixtures' / case['capture_file']).read_text().splitlines()
    rows = [re.sub('─{8,}', '─' * 215, row) if set(re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', row).strip()) == {'─'} else row for row in rows]
    y = case['cursor_y']
    value, cursor, pending = '', 0, b''
    decoder = codecs.getincrementaldecoder('utf-8')()

    def draw():
        visible = list(rows)
        visible[y] = '\x1b[94m>\x1b[39m' + (' ' + value if value else '')
        screen = '\x1b[?2004h\x1b[2J\x1b[H'
        screen += ''.join(f'\x1b[{index + 1};1H' + row for index, row in enumerate(visible))
        screen += f'\x1b[{y + 1};{cursor + 3}H'
        os.write(1, screen.encode())

    draw()
    while True:
        data = os.read(0, 4096)
        if not data:
            return
        with (directory / 'wire.bin').open('ab') as stream:
            stream.write(data)
        pending += data
        while pending:
            homes = (b'\x1b[H', b'\x1bOH', b'\x1b[1~', b'\x1b[7~')
            home = next((item for item in homes if pending.startswith(item)), None)
            if home:
                cursor = 0
                pending = pending[len(home):]
            elif pending.startswith(b'\x1b[200~'):
                end = pending.find(b'\x1b[201~', 6)
                if end < 0:
                    break
                text = decoder.decode(pending[6:end])
                value = value[:cursor] + text + value[cursor:]
                cursor += len(text)
                pending = pending[end + 6:]
            elif any(item.startswith(pending) for item in homes + (b'\x1b[200~',)):
                break
            else:
                count = next((i for i, byte in enumerate(pending) if byte == 27), len(pending))
                if not count:
                    raise ValueError('unexpected fixture key sequence')
                text = decoder.decode(pending[:count])
                value = value[:cursor] + text + value[cursor:]
                cursor += len(text)
                pending = pending[count:]
            draw()


def main():
    parser = argparse.ArgumentParser(description='Explicit copied-root UI isolation; this does not prove routing authority.')
    parser.add_argument('--ui-only', action='store_true', required=True)
    parser.add_argument('suite', choices=['all', 'defaults', 'real-capture', 'paste-collision', 'enter', 'delivery', 'state', 'input'])
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    isolated = output / 'isolated'
    shutil.copytree(ROOT / 'tools', isolated / 'tools')
    shutil.copytree(ROOT / 'tests', isolated / 'tests', ignore=shutil.ignore_patterns('__pycache__'))
    (isolated / 'tools/relay-route-guard').write_text('#!/bin/sh\nprintf \'%s\\n\' \'{}\'\n')
    (output / 'scope.json').write_text(json.dumps({'scope': 'UI transport only; routing explicitly stubbed in copied root', 'production_root': str(ROOT), 'isolated_root': str(isolated)}, indent=2) + '\n')
    env = dict(os.environ, RELAY_AUTHORITY_TOOLS=str(ROOT / 'tools'), RELAY_EVIDENCE_DIR=str(output))
    commands = {
        'defaults': [sys.executable, str(isolated / 'tests/relay-defaults-regression.py')],
        'real-capture': [sys.executable, str(isolated / 'tests/relay-real-capture-lab.py'), str(output / 'real-capture')],
        'paste-collision': ['bash', str(isolated / 'tests/relay-paste-collision-regression.sh')],
        'enter': [sys.executable, str(isolated / 'tests/relay-enter-composer-regression.py'), str(output / 'enter')],
        'delivery': [sys.executable, str(isolated / 'tests/relay-delivery-regression.py'), '--output', str(output / 'delivery')],
        'state': [sys.executable, str(isolated / 'tests/relay-state-regression.py'), '--output', str(output / 'state')],
        'input': ['bash', str(isolated / 'tests/relay-input-guard-regression.sh')],
    }
    suites = ['defaults', 'real-capture', 'paste-collision'] if args.suite == 'all' else [args.suite]
    if 'paste-collision' in suites:
        fixture = output / 'agy-fixture'
        fixture.mkdir()
        source = fixture / 'actor.c'
        source.write_text('#include <sys/wait.h>\n#include <unistd.h>\nint main(int n,char **v){if(n<2)return 1;pid_t p=fork();if(p<0)return 1;if(!p){execvp(v[1],v+1);_exit(127);}int s;waitpid(p,&s,0);return 0;}\n')
        subprocess.run(['cc', str(source), '-o', str(fixture / 'agy')], check=True)
        launcher = fixture / 'launch'
        launcher.write_text('#!/bin/sh\nexec ' + shlex.join([str(fixture / 'agy'), sys.executable, str(Path(__file__).resolve()), '--agy-fixture', str(fixture)]) + '\n')
        launcher.chmod(0o700)
        env['AGY_BIN'] = str(launcher)
    results = []
    print('UI-only copied-root transport checks; actual source cases in delivery use the production authority tools.', flush=True)
    for suite in suites:
        with (output / (suite + '.log')).open('w') as log:
            result = subprocess.run(commands[suite], env=env, stdout=log, stderr=subprocess.STDOUT)
        results.append({'suite': suite, 'exit': result.returncode})
        (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
        print(suite + ': ' + ('PASS' if result.returncode == 0 else 'FAIL'), flush=True)
        if result.returncode:
            return result.returncode
    return 0


if __name__ == '__main__':
    if sys.argv[1:2] == ['--agy-fixture']:
        agy_fixture(sys.argv[2])
    else:
        sys.exit(main())
