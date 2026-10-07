#!/usr/bin/env python3
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
footer = 'Fast off · GPT-6.1-Sol low · ~/.config'
base = (ROOT / 'tests/fixtures/codex-model-1601-terra-derived.ansi').read_text()
checks = 0
for guard in ['codex-model-guard', 'codex-new-guard']:
    for mode in ['models', 'navigate-models']:
        p = subprocess.run([str(ROOT / 'tools' / guard), mode, footer], input=base, text=True, capture_output=True)
        assert p.returncode == 0, (guard, mode, p.stderr)
        if mode == 'navigate-models':
            assert p.stdout.strip() == '5:0', p.stdout
        checks += 1
    for bad in [base.replace('GPT-5.6-Luna', 'Unknown-model'), base.replace('  7. GPT-5.6-Luna', '  8. GPT-5.6-Luna'), base.replace('Older balanced model', 'Unknown description'), base.replace(' select · ', ' unverified · '), base.replace('Select Model and Effort', 'Unexpected picker')]:
        assert bad != base
        p = subprocess.run([str(ROOT / 'tools' / guard), 'models', footer], input=bad, text=True, capture_output=True)
        assert p.returncode == 1, (guard, bad)
        checks += 1
fresh = (ROOT / 'tests/fixtures/codex-new-live-config-main-after.ansi').read_text()
for screen in [fresh, fresh.replace('v0.160.0', 'v0.160.1'), fresh.replace('v0.160.0', 'v0.161.0')]:
    p = subprocess.run([str(ROOT / 'tools/codex-model-guard'), 'settling-reset', footer], input=screen, text=True, capture_output=True)
    assert p.returncode == 0, p.stderr
    checks += 1
    for row in ['  Unexpected status text', '  ⚠ Unknown warning', '  Select Model and Effort', '  Where should the new conversation run?', '› 1. Unknown choice', '  Tip: Unknown command', '  Unknown greeting']:
        bad = screen.replace('\n\x1b[1m›', '\n' + row + '\n\x1b[1m›')
        assert bad != screen
        p = subprocess.run([str(ROOT / 'tools/codex-model-guard'), 'settling-reset', footer], input=bad, text=True, capture_output=True)
        assert p.returncode == 1, (row, p.stdout, p.stderr)
        checks += 1
    for bad in [screen.replace('excellent conversational potential', 'unknown greeting'), screen.replace('desktop app', 'unknown action'), screen.replace('Context 0%', 'Context 1%'), screen.replace('YOLO mode', 'Unknown mode'), screen.replace('>_ OpenAI', '\x1b]8;;https://example.test\x07>_ OpenAI')]:
        if bad == screen:
            continue
        p = subprocess.run([str(ROOT / 'tools/codex-model-guard'), 'settling-reset', footer], input=bad, text=True, capture_output=True)
        assert p.returncode == 1, (bad, p.stderr)
        checks += 1
print(f'PASS {checks} picker and strict settling-reset rejection checks')
