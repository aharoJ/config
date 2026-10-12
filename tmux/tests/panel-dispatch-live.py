#!/usr/bin/env python3
import json
import datetime as dt
import hashlib
import os
from pathlib import Path
import runpy
import subprocess
import sys
import time
from types import SimpleNamespace

sys.dont_write_bytecode = True
API = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/panel-dispatch'))
output = Path(sys.argv[1]).resolve()
output.mkdir(mode=0o700)
protocol = (Path.home() / '.skills/review-protocol').resolve()
session = 'lab-panel-dispatch'
kind = sys.argv[2] if len(sys.argv) > 2 else 'fable'
model = dict(fable='claude-sonnet-5-5', deepseek='deepseek-flash', astra='gpt-6-sol')[kind]
identity = dict(topic='config-dispatch-fixture', cycle_type='implementation', cycle='owned-native-pilot', round=1)


def put(name, value):
    path = output / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value if isinstance(value, bytes) else (json.dumps(value) + '\n').encode())
    return API['ref'](path)


def tmux(*arguments):
    return subprocess.check_output([os.environ['TMUX_BIN'], '-L', os.environ['TMUX_LAB_SOCKET'], '-f', '/dev/null', *arguments], text=True).strip()


prepared = launched = None
try:
    project = output / 'project'
    intake = put('project/reviews/config-dispatch-fixture/intakes/audit-r1.md', b'Owned delivered input: alpha beta.\n')
    manifest = put('project/reviews/config-dispatch-fixture/intakes/audit-r1.manifest.json', dict(status='PASS', output=intake['path'], sha256='sha256:' + intake['sha256'], bytes=Path(intake['path']).stat().st_size))
    delivered = put('delivered.md', Path(intake['path']).read_bytes())
    read_instruction = 'Read PROMPT.md and intake.md fully using Read.'
    if kind == 'astra':
        read_instruction = 'Preliminary prompt reads do not disqualify this pilot. Now read PROMPT.md and intake.md fully with two exec calls using these exact bodies: const r = await tools.exec_command({cmd:"cat PROMPT.md"}); text(r); and const r = await tools.exec_command({cmd:"cat intake.md"}); text(r); The authorized cat reads are not test execution; after these full-result reads, do not repeat them.'
    prompt = put('prompt.md', ('Operator-authorized native dispatcher pilot. ' + read_instruction + ' No reads outside this seat, no test execution and no peer messages. Reply exactly with two lines:\nGrounded check: owned input contains alpha beta; no tests executed.\nVerdict: PASS\n').encode())
    projection = put('projection.json', dict(context=identity, canonical_input=intake, delivered_input=delivered, prompt=prompt, exclusion_pass=True, fidelity_pass=True, independent=True, unknown_fields=[], test_fixture_only=True))
    launcher = put('launcher.json', dict(context=identity, adapter=API['adapter'](), authorized=True, tai_sha256=API['ref'](API['REPO'] / 'fish/internal/tmux/tai.fish')['sha256'], trust_sha256=API['ref'](API['TOOLS'] / 'panel-seat-trust')['sha256'], test_fixture_only=True))
    policy = put('policy.json', dict(context=identity, authorized=True, authorized_at=API['now'](), max_redispatches=0, technical_causes=[], exhaustion='non-response', test_fixture_only=True))
    request = put('request.json', dict(version='1', project_root=str(project), protocol_root=str(protocol), **identity, session=session, packet=dict(canonical_input=intake, manifest=manifest, delivered_input=delivered, prompt=prompt, projection_review=projection), roster=[dict(seat_id=kind + '-cli', attempt_id='a', transport=kind, window=kind, model=model, effort='low', accepted_limitations=[])], redispatch_policy_ref=policy, launcher_ref=launcher, deadline_seconds=90, authorized=True, authorized_at=API['now']()))
    tmux('new-session', '-d', '-s', session, '-n', 'hold', '-x', '215', '-y', '50', 'exec sleep 2147483647')
    tmux('set-option', '-t', session, 'automatic-rename', 'off')
    prepared_ref = API['prepare'](SimpleNamespace(request=request['path'], sha256=request['sha256'], batch=str(output / 'batch')))
    prepared = API['read'](prepared_ref)
    launched_ref = API['launch'](SimpleNamespace(prepared=prepared_ref['path'], sha256=prepared_ref['sha256']))
    launched = API['read'](launched_ref)
    seat = launched['seats'][0]
    project_logs = Path.home() / '.claude/projects' / __import__('re').sub('[^A-Za-z0-9-]', '-', seat['directory'])
    if kind == 'astra':
        project_logs = Path.home() / '.local/state/codex-panel-home/sessions' / dt.datetime.now().strftime('%Y/%m/%d')
    deadline = time.monotonic() + 180
    diagnostics = None
    last_error = 'native transcript unavailable'
    while time.monotonic() < deadline:
        candidates = list(project_logs.glob('*.jsonl'))
        if kind == 'astra':
            candidates = [path for path in candidates if json.loads(path.open().readline()).get('payload', {}).get('cwd') == seat['directory']]
        if len(candidates) == 1:
            native = candidates[0]
            try:
                data = API['path_bytes'](native)
                diagnostics = API['inspect_native'](data, API['KINDS'][kind], seat, API['read'](request))
                break
            except (OSError, ValueError) as error:
                last_error = str(error)
        time.sleep(.5)
    put('final-screen.ansi', tmux('capture-pane', '-p', '-e', '-t', seat['pane']['pane_id']).encode())
    if diagnostics is None:
        put('FAIL.json', dict(error=last_error))
        raise AssertionError(last_error)
    native_ref = put('observed-native.jsonl', data)
    put('diagnostics.json', diagnostics)
    boundary = put('boundary.json', dict(context=identity, seat_id=seat['seat_id'], attempt_id=seat['attempt_id'], session_id=diagnostics['session_id'], native_ref=native_ref, descendants=[], launch_ref=launched_ref, pane=seat['pane'], session_binding_verified=True, final_sha256=hashlib.sha256(diagnostics['final_text'].encode()).hexdigest(), raw_verdict=diagnostics['raw_verdict'], independent=True, isolation_pass=True, external_input_pass=True, test_fixture_only=True))
    index = put('native-index.json', dict(context=identity, launch_ref=launched_ref, seats=[dict(seat_id=seat['seat_id'], attempt_id=seat['attempt_id'], native_ref=native_ref, format=API['KINDS'][kind], descendants=[], boundary_review_ref=boundary, account_ref=None)]))
    collected = API['collect'](SimpleNamespace(launched=launched_ref['path'], sha256=launched_ref['sha256'], native_index=index['path'], native_sha256=index['sha256']))
    cleaned = API['cleanup'](SimpleNamespace(launched=launched_ref['path'], sha256=launched_ref['sha256'], collected=collected['path'], collected_sha256=collected['sha256'], output=str(output / 'cleanup.json')))
    launched = None
    put('PASS.json', dict(native_collected=True, cleanup_ref=cleaned, qualification='not claimed: test control proofs only'))
    print('PASS actual ' + kind + ' dispatch, one sanctioned Start, native reads/final/model, collection and owned cleanup')
finally:
    if launched is not None or prepared is not None:
        rows = (launched or prepared)['seats']
        for seat in rows:
            folder = Path(seat['directory'])
            temp = Path('/private/tmp') / ('panel-' + str(folder.stat().st_ino))
            if temp.is_dir() and not temp.is_symlink() and (temp / '.panel-seat').read_text() == str(folder) + '\n':
                subprocess.run(['trash', str(temp)], check=True)
            if launched is not None:
                try:
                    pane = API['exact_pane'](session, seat['window'])
                    tmux('kill-window', '-t', pane['window_id'])
                except (OSError, ValueError, subprocess.CalledProcessError):
                    pass
            trust = {}
            exec(compile(API['path_bytes'](API['TOOLS'] / 'panel-seat-trust'), str(API['TOOLS'] / 'panel-seat-trust'), 'exec'), trust)
            if kind in ('fable', 'deepseek'):
                config = Path.home() / '.claude.json'
                with trust['DirLock'](config):
                    value = json.loads(config.read_text())
                    for key in (str(folder), '/tmp' + str(folder)[len('/private/tmp'):]):
                        value.get('projects', {}).pop(key, None)
                    trust['write_atomic'](config, json.dumps(value, indent=2), config.stat().st_mode & 0o777)
            elif kind == 'astra':
                config = Path.home() / '.local/state/codex-panel-home/config.toml'
                with trust['DirLock'](config):
                    text = config.read_text()
                    for key in (str(folder), '/tmp' + str(folder)[len('/private/tmp'):]):
                        text = __import__('re').sub(r'(?m)^\[projects\."' + __import__('re').escape(key) + r'"\]\ntrust_level = "trusted"\n?', '', text)
                    trust['write_atomic'](config, text, config.stat().st_mode & 0o777)
            subprocess.run(['trash', str(folder)], check=True)
