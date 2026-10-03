#!/usr/bin/env python3
# path: ~/.config/tmux/tests/codex-new-ansi-regression.py
# description: Replay accepted and refused corpora under intensity-preserving SGR variants.
# date: 2026-10-03
import ast
import contextlib
import hashlib
import importlib.util
import io
import json
import pathlib
import re
import runpy
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures'
spec = importlib.util.spec_from_file_location('ansi_variants', root / 'tests/codex-new-ansi-variants.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
variants = module.variants
guard = root / 'tools/codex-new-guard'
input_guard = root / 'tools/relay-input-guard'
real_run = subprocess.run
guard_cases, chat_cases = [], []


def collect(*args, **kwargs):
    result = real_run(*args, **kwargs)
    argv = args[0]
    if str(argv[0]) == str(guard) and 'input' in kwargs:
        guard_cases.append((argv[1], kwargs['input'], argv[2], result.returncode, result.stdout))
    return result


subprocess.run = collect
try:
    with contextlib.redirect_stdout(io.StringIO()):
        runpy.run_path(str(root / 'tests/codex-new-guard-regression.py'))
finally:
    subprocess.run = real_run
source = root / 'tests/codex-new-chat-regression.py'
tree = ast.parse(source.read_text())
for node in tree.body:
    if isinstance(node, ast.FunctionDef) and node.name == 'check':
        node.body = ast.parse('global checks\nchat_cases.append((screen, expected_code, expected, cursor_x, cursor_y))\nchecks += 1').body
namespace = {'__file__': str(source), 'chat_cases': chat_cases}
with contextlib.redirect_stdout(io.StringIO()):
    exec(compile(ast.fix_missing_locations(tree), str(source), 'exec'), namespace)
checks = 0
counts = {'guard_cases': len(guard_cases), 'chat_cases': len(chat_cases), 'input_cases': 0, 'variants': {}}


def run(args, capture):
    global checks
    result = real_run(args, input=capture, text=True, capture_output=True)
    checks += 1
    return result


for mode, capture, footer, wanted, stdout in guard_cases:
    for name, variant in variants(capture):
        result = run([str(guard), mode, footer], variant)
        assert result.returncode == wanted and result.stdout == stdout, ('guard', mode, name, wanted, result.returncode)
        counts['variants'][name] = counts['variants'].get(name, 0) + 1
for case in json.loads((fixtures / 'codex-new-reset-ansi.json').read_text())['cases']:
    raw = (fixtures / case['capture_file']).read_text()
    assert hashlib.sha256(raw.encode()).hexdigest() == case['sha256']
    chat_cases.append((raw, 0, case['footer'], case['cursor_x'], case['cursor_y']))
for case in json.loads((fixtures / 'codex-new-blind-retained.json').read_text())['cases']:
    raw = (fixtures / case['capture_file']).read_text()
    assert hashlib.sha256(raw.encode()).hexdigest() == case['sha256']
    footer = run([str(guard), 'footer'], raw).stdout.strip()
    y = next(i for i, row in enumerate(raw.splitlines()) if re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', row).startswith('› '))
    chat_cases.append((raw, 4, footer, 2, y))
for capture, wanted, footer, x, y in list(chat_cases):
    if wanted == 0 and '\x1b[2mAsk Codex to do anything' in capture:
        typed = capture.replace('\x1b[2mAsk Codex to do anything', '\x1b[22mAsk Codex to do anything')
        chat_cases.append((typed, 4, footer, x, y))
for capture, wanted, footer, x, y in chat_cases:
    for name, variant in variants(capture):
        if run([str(guard), 'menu', footer], variant).returncode == 0:
            actual = 0
        elif run([str(guard), 'direct-reset', footer], variant).returncode == 0:
            actual = 0 if run([str(input_guard), '›', str(x), str(y), '215', 'strict'], variant).returncode == 0 else 4
        else:
            actual = 4
        assert actual == wanted, ('chat', name, wanted, actual, capture)
for manifest in sorted(fixtures.glob('*.json')):
    for case in json.loads(manifest.read_text()).get('cases', []):
        if 'input_exit' not in case or case['input_exit'] == 0:
            continue
        raw = case.get('capture')
        if raw is None:
            raw = (fixtures / case['capture_file']).read_text()
        wanted = case['input_exit']
        counts['input_cases'] += 1
        for name, variant in variants(raw):
            result = run([str(input_guard), case.get('glyph', '›'), str(case['cursor_x']), str(case['cursor_y']), str(case.get('pane_width', 215)), 'strict'], variant)
            assert result.returncode == wanted, ('input', manifest.name, case['name'], name, wanted, result.returncode)
shell = (root / 'tests/relay-input-guard-regression.sh').read_text()
body = shell.split('# Captures reproduce the SGR classes observed in live Codex and Claude panes.\n', 1)[1].split('\nexpect_relay ', 1)[0]
script = "set -eu\nexpect_guard() { printf '%s\\0' \"$#\" \"$@\"; }\n" + body
inventory = real_run(['bash', '-c', script], capture_output=True, text=True, check=True).stdout.split('\0')
counts['shell_refusal_cases'] = 0
position = 0
while position < len(inventory) - 1:
    length = int(inventory[position])
    args = inventory[position + 1:position + 1 + length]
    position += length + 1
    wanted, glyph, name, capture, x, y, *extra_args = args
    if int(wanted) == 0:
        continue
    counts['shell_refusal_cases'] += 1
    for variant_name, variant in variants(capture):
        result = run([str(input_guard), glyph, x, y, *extra_args], variant)
        assert result.returncode == int(wanted), ('shell refusal', name, variant_name, wanted, result.returncode)
counts['chat_cases'] = len(chat_cases)
counts['checks'] = checks
print('codex ANSI variance:', json.dumps(counts, sort_keys=True), 'PASS')
