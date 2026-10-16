#!/bin/sh
# External preflight and launch are one fail-closed command. No rg dependency.
umask 077
if [ "$#" -ne 1 ]; then
    exit 64
fi
preflight() {
    /usr/bin/python3 -B - "$1" <<'PY'
from pathlib import Path
import hashlib
import json
import subprocess
import sys

try:
    base = (Path.home() / 'desk/audits/relay/rustify/review')
    source_pin = sys.argv[1]
    manifest = base / 'k71-launch-manifest.sha256'
    checks = {}
    r = subprocess.run(['/usr/bin/shasum', '-a', '256', str(manifest)], capture_output=True, check=True)
    if r.stdout.decode().split()[0] != source_pin:
        raise RuntimeError('external launch-manifest pin mismatch')
    checks['external_manifest_digest'] = r.stdout.decode()
    for name in ['k71-review-sha256.txt', 'k71-launch-manifest.sha256', 'k71-artifacts-sha256.txt', 'k69a-evidence-sha256.txt']:
        r = subprocess.run(['/usr/bin/shasum', '-a', '256', '-c', str(base / name)], capture_output=True, check=True)
        checks[name] = r.stdout.decode()
    result = (Path.home() / 'desk/tmp/k69-codex-startup-20261014/result.json')
    result_pin = '9e06c4c18c6e798194465a43286d494eaf036851aa249998b73ce37bbc225908'
    r = subprocess.run(['/usr/bin/shasum', '-a', '256', str(result)], capture_output=True, check=True)
    if r.stdout.decode().split()[0] != result_pin:
        raise RuntimeError('accepted Stage A result changed')
    checks['stage_a_result_digest'] = r.stdout.decode()
    review = base / 'red-k71-stage-b.md'
    marker = 'K69_STAGE_B_CLEARANCE ' + source_pin + ' ' + result_pin
    subprocess.run(['/usr/bin/grep', '-Fx', marker, str(review)], stdout=subprocess.DEVNULL, check=True)
    checks['review_marker_matches'] = True
    checks['red_review_sha256'] = hashlib.sha256(review.read_bytes()).hexdigest()
    dry_run = json.loads((base / 'k71-private-dryrun.json').read_bytes())
    if dry_run.get('source_pin') != source_pin or dry_run.get('fixture_only') is not True:
        raise RuntimeError('private dry run does not match candidate')
    original = Path(dry_run['result_path']).read_bytes()
    if hashlib.sha256(original).hexdigest() != dry_run['result_sha256']:
        raise RuntimeError('private dry-run result changed')
    checks['private_dry_run_result_sha256'] = dry_run['result_sha256']
    root = (Path.home() / 'desk/tmp/k71-codex-keepers-20261014')
    if root.exists():
        raise RuntimeError('fresh Stage B root already exists')
    (base / 'k71-run-preflight.json').write_text(json.dumps(dict(source_pin=source_pin, root_absent=True, checks=checks), indent=2) + '\n')
    print('External preflight passed; launching the one cleared Stage B command.', flush=True)
except Exception as exc:
    def clean(value):
        return None if value is None else str(value).replace(str(Path.home()), '$HOME').replace('\n', '?')[:1200]
    detail = dict(event='preflight-exception', exception_type=type(exc).__name__,
                  message=('subprocess returned exit ' + str(exc.returncode)) if isinstance(exc, subprocess.CalledProcessError) else clean(getattr(exc, 'strerror', None) or str(exc)),
                  missing_path=clean(getattr(exc, 'filename', None)))
    print(json.dumps(detail), file=sys.stderr)
    raise SystemExit(1)
PY
}
# Resolve this checkout and the operator's home without embedding machine paths.
fixture_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
keeper_desk="$HOME/desk"
keeper_review="$keeper_desk/audits/relay/rustify/review"
keeper_tmp="$keeper_desk/tmp"
preflight "$1" && exec /usr/bin/python3 -B "$fixture_dir/window-native-e2e.py" --pin "$1" --mode codex-keepers --private-dry-run "$keeper_review/k71-private-dryrun.json" --stage-a-result "$keeper_tmp/k69-codex-startup-20261014/result.json" --stage-b-review "$keeper_review/red-k71-stage-b.md" "$keeper_tmp/angelstar-worktree-target/debug/angelstar-runtime" "$keeper_tmp/k71-codex-keepers-20261014"
