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
print(f'PASS {checks} Terra-selected derived picker and rejection checks for both guards')
