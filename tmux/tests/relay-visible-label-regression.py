#!/usr/bin/env python3
import pathlib
import runpy

module = runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1] / 'tools/relay-visible-label'))
parse = module['model_state']
footer = '\x1b[38;2;1;2;3m  Fast off · GPT-5.6-Terra max · ~/lab · Context 43% used\x1b[0m'
assert parse('› Ask Codex to do anything\n\n'+footer, 0, 'codex') == 'gpt-5.6-terra max'
assert parse(footer, 1, 'codex') == 'model/effort unverified'
for invalid in (footer+ '\n'+footer, footer.replace('\x1b[38;2;1;2;3m',''), footer.replace('max', 'invented'), '\x1b[48;2;1;2;3m'+footer, '\x1b]8;;fake\x1b\\'+footer):
    assert parse('› draft\n\n'+invalid, 0, 'codex') == 'model/effort unverified'
cc = '\x1b[38;2;1;2;3m  Opus 5.5  |  context 100k / 1.0M 10% | cache 100% | session 100k | effort low | v2.1.290\x1b[0m'
assert parse('❯\n\n'+cc, 0, 'claude') == 'opus-5.5 low'
agy = '\x1b[38;2;1;2;3m? for shortcuts                  Gemini 3.8 Flash · high\x1b[0m'
assert parse('>\n\n'+agy, 0, 'agy') == 'gemini-3.8-flash high'
assert parse('>\n\n'+agy, 0, 'gemini') == 'gemini-3.8-flash high'
assert module['label'](dict(session='vetmed-absence-expansion',window='terra'), 'gpt-5.6-terra max') == 'terra (vetmed-absence-expansion:terra) [gpt-5.6-terra max]'
print('PASS: window identity and live styled footer models; historical/plain/duplicate/background/OSC/invented-effort candidates remain unverified')
