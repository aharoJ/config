from pathlib import Path
import runpy
import tempfile

ROOT = Path(__file__).resolve().parents[1]
module = runpy.run_path(str(ROOT / 'tools/relay-agent-identity'))
home = module['HOME_ROOT']
installation = module['installation']
daemon = '.codex/packages/app-server-daemon/releases/999.123.456-aarch64-apple-darwin/'
npm = '.local/share/fnm/node-versions/v999.0.0/installation/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/'
allowed = [daemon + 'codex', daemon + 'bin/codex', npm + 'codex/codex', npm + 'bin/codex']
denied = [daemon + 'bin/codex-helper', daemon + 'bin/extra/codex', daemon + 'other/codex',
          npm + 'other/codex', npm + 'bin/extra/codex', '.local/bin/codex',
          '.codex/packages/app-server-daemon/bin/codex',
          npm.replace('@openai/codex/', '@other/codex/') + 'bin/codex']
for relative in allowed:
    assert installation(home / relative) == 'codex', relative
    assert installation(Path('/tmp') / relative) is None, relative
for relative in denied:
    assert installation(home / relative) is None, relative
with tempfile.TemporaryDirectory(prefix='identity-', dir=home / 'desk/lab') as value:
    path = Path(value) / 'actor'
    path.write_text('fixture')
    path.chmod(0o600)
    initial = module['stamp'](path)
    path.chmod(0o622)
    try:
        module['stamp'](path)
    except ValueError:
        pass
    else:
        raise AssertionError('writable actor accepted')
    path.chmod(0o600)
    path.write_text('replacement fixture')
    assert module['stamp'](path) != initial
print('PASS four rolling native layouts, twelve noncanonical roots, unsafe modes and replacement stamps')
