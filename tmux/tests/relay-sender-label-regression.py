import importlib.util
import json
import os
from pathlib import Path
import runpy
import sys
from unittest.mock import patch

output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
root = Path(__file__).resolve().parents[1]
label = runpy.run_path(str(root / 'tools/relay-sender-label'))
origin = label['origin']
namespace = origin.__globals__
checks = []
pane = ['%4', 'review-protocol', 'codex', 'node', '100', '0']
for agent in ['codex', 'claude', 'agy', 'gemini', 'unknown']:
    table = {300:(200,'/usr/bin/bash'),200:(100,'/lab/'+agent),100:(1,'/usr/bin/fish')}
    with patch.dict(namespace, processes=lambda:table), patch.dict(os.environ, CC_MSG_FROM='claude', TMUX_PANE='%999'):
        result = origin(300, [pane])
    expected = agent if agent != 'unknown' else 'relay'
    assert result[0] == ('%4','review-protocol','codex','100',expected), result
    checks.append(dict(case='nearest-'+agent, result=result[0]))
table = {300:(200,'/lab/codex'),200:(100,'/lab/claude'),100:(1,'/usr/bin/fish')}
with patch.dict(namespace, processes=lambda:table):
    assert origin(300, [pane])[0][-1] == 'codex'
    for name, rows in [('ambiguous',[pane,pane]),('unsafe',[[*pane[:1],'bad session',*pane[2:]]]),('missing',[])]:
        assert origin(300,rows) is None
        checks.append(dict(case=name,refused=True))
    checks.append(dict(case='worker-under-claude',agent='codex'))
source = root / 'tests/relay-delivery-regression.py'
spec = importlib.util.spec_from_file_location('delivery', source)
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)
matrix = fixtures.Matrix(output/'transport')
try:
    for agent in ['codex','agy','gemini','bash']:
        matrix.sender_case('verified-'+agent,agent)
    matrix.sender_case('codex-node','codex',node=True)
    matrix.sender_case('renamed-codex','codex',rename=True,code=1)
    matrix.sender_case('ambiguous-codex','codex',linked=True,code=1)
finally:
    matrix.close()
assert all(row['passed'] for row in matrix.results), matrix.results
(output/'ancestry.json').write_text(json.dumps(checks,indent=2)+'\n')
print(f'PASS: {len(checks)} ancestry checks and {len(matrix.results)} private sender-label transport cases')
