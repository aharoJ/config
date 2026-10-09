import json
from pathlib import Path
import runpy

IDENTITY = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/relay-agent-identity'))


def enable(tools, registry, socket):
    path = tools / 'relay-agent-identity'
    text = path.read_text().replace('TEST_ATTESTATIONS = None', 'TEST_ATTESTATIONS = ' + repr(str(registry)))
    text = text.replace('TEST_SOCKET = None', 'TEST_SOCKET = ' + repr(str(socket)))
    path.write_text(text)
    if not registry.exists():
        registry.write_text('[]')
        registry.chmod(0o600)


def attest(registry, app, executable, entrypoint=None):
    row = dict(app=app, executable=IDENTITY['stamp'](Path(executable).resolve()), entrypoint=IDENTITY['stamp'](Path(entrypoint).resolve()) if entrypoint else [None])
    rows = json.loads(registry.read_text())
    rows = [item for item in rows if item['executable'][0] != row['executable'][0] or item['entrypoint'][0] != row['entrypoint'][0]] + [row]
    temporary = registry.with_suffix('.new')
    temporary.write_text(json.dumps(rows))
    temporary.chmod(0o600)
    temporary.replace(registry)
