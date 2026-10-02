#!/usr/bin/env python3
# path: ~/.config/tmux/tests/codex-new-guard-regression.py
# description: Exercise fresh-chat screen guards with captured menu and hostile variants.
# patched: require current-checkout highlight and reject unfamiliar menu content
# date: 2026-10-02
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
guard = root / 'tools/codex-new-guard'
menu = (root / 'tests/fixtures/codex-new-menu.ansi').read_text()
checks = 0


def check(mode, capture, expected_code, footer='Fast off · GPT-6-Astra low · ~/.config'):
    global checks
    p = subprocess.run([str(guard), mode, footer], input=capture, text=True, capture_output=True)
    assert p.returncode == expected_code, (mode, p.returncode, expected_code, p.stderr)
    checks += 1


check('menu', menu, 0)
for mutated in [menu.replace('› 1.', '  1.').replace('  2.', '› 2.'),
                menu.replace('\x1b[1;7m', '\x1b[1m'),
                menu.replace('Current checkout', 'Other checkout'),
                menu.replace('New worktree', 'New directory'),
                menu + 'unknown overlay\n', menu + menu,
                menu.replace('enter', 'space'),
                menu.replace('current working directory', 'another working directory')]:
    check('menu', mutated, 1)
footer = 'Fast off · GPT-6-Astra low · ~/.config'
slash = '\x1b[1;7m› /new  \x1b[0;7mstart a new chat during a conversation\x1b[0m\n\n› /new\n\n  ' + footer + ' · Context 43% used\n'
check('slash', slash, 0)
for mutated in [slash.replace('› /new\n', '› /new draft\n'), slash.replace('/new  ', '/model  '), slash.replace('\x1b[1;7m', '\x1b[1m'), slash + 'unknown overlay\n', slash.replace('GPT-6-Astra', 'GPT-6-Sol')]:
    check('slash', mutated, 1)
fresh = '› Ask Codex to do anything\n\n  ' + footer + ' · Context 0% used · ← for agents\n'
check('fresh', fresh, 0)
for mutated in [fresh.replace('0%','1%'), fresh.replace('~/.config','~/elsewhere'), fresh.replace(' low',' high'), fresh.replace('Context 0% used','Context 0% used arbitrary')]:
    check('fresh', mutated, 1)
print(f'codex new guard: {checks} checks PASS')
