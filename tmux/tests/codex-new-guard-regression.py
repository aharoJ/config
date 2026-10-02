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
models = (root / 'tests/fixtures/codex-new-models.ansi').read_text()
efforts = (root / 'tests/fixtures/codex-new-efforts.ansi').read_text()
advanced = (root / 'tests/fixtures/codex-new-advanced.ansi').read_text()
model_slash = (root / 'tests/fixtures/codex-new-model-slash.ansi').read_text()
check('models', models, 0)
check('efforts', efforts, 0)
check('advanced', advanced, 0, 'Fast off · GPT-6-Astra ultra · ~/.config')
check('model-slash', model_slash, 0, 'Fast off · GPT-6.1-Sol low · ~/.config')
for mode, capture, footer in [('models', models, 'Fast off · GPT-6-Astra low · ~/.config'),
                              ('efforts', efforts, 'Fast off · GPT-6-Astra high · ~/.config'),
                              ('advanced', advanced, 'Fast off · GPT-6-Astra max · ~/.config')]:
    for mutation in [capture + 'unknown overlay\n', capture.replace('1.', '9.', 1),
                     capture.replace('\x1b[1;7m', '\x1b[1m'),
                     capture.replace('enter', 'space'), capture + capture,
                     capture.replace('› ', '  ', 1)]:
        check(mode, mutation, 1, footer)
check('models', models.replace('Latest workhorse model', 'Unknown model'), 1)
check('efforts', efforts.replace('GPT-6-Astra', 'GPT-6.1-Sol'), 1)
check('advanced', advanced.replace('⚠ Consumes usage limits faster', 'Unknown warning'), 1, 'Fast off · GPT-6-Astra ultra · ~/.config')
for effort in ['low', 'medium', 'high', 'xhigh', 'max', 'ultra']:
    check('efforts', efforts, 0, f'Fast off · GPT-6-Astra {effort} · ~/.config')
for footer in ['Fast off · Unknown-model low · ~/.config', 'Fast off · GPT-6-Astra unknown · ~/.config']:
    check('supported-footer', '', 1, footer)
check('supported-footer', '', 0)
reset = fresh.replace('GPT-6-Astra low', 'GPT-6.1-Sol low')
check('reset', reset, 0)
check('fresh', reset, 1)
check('reset', reset.replace('~/.config', '~/elsewhere'), 1)
check('reset', reset.replace('Fast off', 'Fast on'), 1)
check('reset', reset.rstrip('\n') + '  ⚠ 1 warning · f2 to view\n', 0)
check('reset', reset.rstrip('\n') + '  ⚠ unknown warning\n', 1)
more = (root / 'tests/fixtures/codex-new-effort-more.ansi').read_text()
check('efforts', more, 0, 'Fast off · GPT-6-Astra ultra · ~/.config')
check('efforts', more.replace(' select · ', ' default · s session · '), 1)
check('efforts', efforts.replace(' default · ', ' select · ').replace('\x1b[0;1ms\x1b[0;2m session · ', ''), 1)
current = (root / 'tests/fixtures/codex-new-advanced-current.ansi').read_text()
check('advanced', current, 0, 'Fast off · GPT-6-Astra max · ~/.config')
check('advanced', current.replace(' default · ', ' apply · '), 0, 'Fast off · GPT-6-Astra max · ~/.config')
check('advanced', current.replace(' default · ', ' run · '), 1, 'Fast off · GPT-6-Astra max · ~/.config')
for mode, screen, footer, wanted in [('navigate-models', models, 'Fast off · GPT-6-Astra low · ~/.config', '0:1'),
                                     ('navigate-efforts', efforts, 'Fast off · GPT-6-Astra xhigh · ~/.config', '1:3'),
                                     ('navigate-efforts', more, 'Fast off · GPT-6-Astra low · ~/.config', '4:0'),
                                     ('navigate-advanced', advanced, 'Fast off · GPT-6-Astra ultra · ~/.config', '0:1')]:
    p = subprocess.run([str(guard), mode, footer], input=screen, text=True, capture_output=True)
    assert p.returncode == 0 and p.stdout.strip() == wanted, (mode, p.stdout, p.stderr)
    checks += 1
for mode, screen, footer in [('menu', menu, 'Fast off · GPT-6-Astra low · ~/.config'),
                             ('slash', slash, 'Fast off · GPT-6-Astra low · ~/.config'),
                             ('model-slash', model_slash, 'Fast off · GPT-6.1-Sol low · ~/.config'),
                             ('models', models, 'Fast off · GPT-6-Astra low · ~/.config'),
                             ('efforts', efforts, 'Fast off · GPT-6-Astra high · ~/.config'),
                             ('advanced', advanced, 'Fast off · GPT-6-Astra max · ~/.config')]:
    color = '\x1b[1m\x1b[38;2;0;0;46m\x1b[48;2;99;168;248m'
    colored = screen.replace('\x1b[1;7m', color)
    check(mode, colored, 0, footer)
    for bad in [color.replace('\x1b[1m', ''), color.replace('48;2;99;168;248', '49'),
                color.replace('248', '256'), color + '\x1b[0m', color + '\x1b[22m']:
        check(mode, screen.replace('\x1b[1;7m', bad), 1, footer)
for mode in ('models', 'efforts', 'advanced'):
    live = (root / ('tests/fixtures/codex-new-colored-' + mode + '.ansi')).read_text()
    check(mode, live, 0, 'Fast off · GPT-5.6-Terra max · ~/.config')
print(f'codex new guard: {checks} checks PASS')
