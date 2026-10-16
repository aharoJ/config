#!/usr/bin/python3
"""Agent-driven visible native E2E in one owned window; no PID signals."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import select
import shlex
import sqlite3
import subprocess
import sys
import time
import uuid

EXPECTED_RUNTIME = '6173def5b451630a072a8276fddcf7bd276c0c7f8d5b7985ca1e6e7916dc70cb'
PROBE = (Path.home() / 'desk/tmp/angelstar-worktree-target/debug/deps/angelstar_runtime-5242d787eab9e3d7')
EXPECTED_PROBE = 'b3e358c2fc690792ace9b54c32e858059c44cd12bc96d8a905fd9f511b58812b'
SOURCE_MANIFEST = Path.home() / 'desk/audits/relay/rustify/review/k71-source-before-sha256.txt'
ACCEPTED_STAGE_A_RESULT = '9e06c4c18c6e798194465a43286d494eaf036851aa249998b73ce37bbc225908'
SESSION = 'config(tmux-to-rust)'
TMUX = '/opt/homebrew/bin/tmux'
SOCKET = '/private/tmp/tmux-%d/default' % os.geteuid()
IMAGES = {
    'claude': ('.local/share/claude/versions/2.1.299', 'ba5ab7b8c195fa03ab8d5bf3915c76153b576a2c40e79a5c46e265e7ed9744b3'),
    'codex': ('.local/share/fnm/node-versions/v22.19.0/installation/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex', '74c6a6d263f40d65f99c27a815275f5b4ed0bcc2baecc396b4cf3255498bdfc0'),
}


GUARD = Path(__file__).resolve().parents[1] / 'cleanup_guard.py'
PRIVATE_CLIENT = Path(__file__).resolve().with_name('private-runtime-line-editor.py')


def exception_details(exc):
    def clean(value):
        if value is None:
            return None
        text = str(value).replace(str(Path.home()), '$HOME')
        return re.sub(r'[\x00-\x1f\x7f]', '?', text)[:1200]
    if isinstance(exc, subprocess.CalledProcessError):
        message = 'subprocess returned exit ' + str(exc.returncode)
    elif isinstance(exc, UnicodeError):
        message = getattr(exc, 'reason', 'Unicode conversion failed')
    elif isinstance(exc, json.JSONDecodeError):
        message = '%s; line=%s column=%s' % (exc.msg, exc.lineno, exc.colno)
    elif isinstance(exc, OSError) and exc.strerror:
        message = exc.strerror
    else:
        message = str(exc)
    return dict(exception_type=type(exc).__name__, message=clean(message),
                missing_path=clean(getattr(exc, 'filename', None)),
                secondary_path=clean(getattr(exc, 'filename2', None)))


def verify_private_dryrun(source_pin, result_path):
    if result_path is None:
        raise RuntimeError('native run requires passing exact-controller private dry run')
    evidence = json.loads(result_path.read_bytes())
    if evidence.get('fixture_only') is not True or evidence.get('source_pin') != source_pin:
        raise RuntimeError('private dry-run evidence does not match candidate')
    original = Path(evidence['result_path']).read_bytes()
    if hashlib.sha256(original).hexdigest() != evidence.get('result_sha256'):
        raise RuntimeError('private dry-run original result changed')
    result = json.loads(original)
    if (result.get('source_pin') != source_pin or result.get('private_fixture') is not True
            or result.get('mode') != 'codex-keepers' or result.get('error') is not None
            or result.get('completed') != [['codex', 'draft'], ['codex', 'positive']]
            or result.get('cleanup_proven') is not True or result.get('private_server_retired') is not True
            or result.get('runtime_sha256') != EXPECTED_RUNTIME or result.get('probe_sha256') != EXPECTED_PROBE
            or result.get('controller_sha256') != hashlib.sha256(Path(__file__).read_bytes()).hexdigest()):
        raise RuntimeError('private dry run is not successful for this exact controller/artifacts')


def verify_source_pin(expected_pin):
    data = SOURCE_MANIFEST.read_bytes()
    if not re.fullmatch(r'[a-f0-9]{64}', expected_pin) or hashlib.sha256(data).hexdigest() != expected_pin:
        raise RuntimeError('reviewed source manifest changed')
    for line in data.decode().splitlines():
        digest, name = line.split('  ', 1)
        if hashlib.sha256(Path(name).read_bytes()).hexdigest() != digest:
            raise RuntimeError('reviewed source changed')


def load_oracles(path):
    # Called only after source-pin verification. Compile the reviewed source
    # directly: neither sys.modules nor any timestamp-valid pyc is consulted.
    namespace = {'__name__': '_keeper_oracles_reviewed_source', '__file__': str(path)}
    exec(compile(path.read_bytes(), str(path), 'exec'), namespace)
    return tuple(namespace[name] for name in
                 ('UUID', 'draft_snapshot', 'pending_no_input', 'exact_turn', 'native_turns'))


def startup_predicates(screen):
    lower = screen.lower()
    return dict(banner='openai codex' in lower, model='gpt-' in lower, prompt='›' in screen,
                blocked_marker=any(word in lower for word in
                    ['trust this', 'trust the files', 'trust this folder', 'log in', 'login',
                     'sign in', 'authenticate', 'api key', 'verification code', 'paste code',
                     'choose the theme', 'select the theme']))


def verify_stage_b(source_pin, result_path, review_path):
    # Separate explicit post-Stage-A review, never an automatic mode transition.
    if result_path is None or review_path is None:
        raise RuntimeError('Stage B requires successful Stage A and its Red review')
    data = result_path.read_bytes()
    result = json.loads(data)
    historical = hashlib.sha256(data).hexdigest() == ACCEPTED_STAGE_A_RESULT
    if (result.get('mode') != 'codex-startup' or (result.get('source_pin') != source_pin and not historical)
            or result.get('error') is not None or result.get('readiness_proven') is not True
            or result.get('cleanup_proven') is not True
            or result.get('completed') != [['codex', 'startup']]
            or (not historical and result.get('runtime_sha256') != EXPECTED_RUNTIME)
            or (not historical and result.get('probe_sha256') != EXPECTED_PROBE)):
        raise RuntimeError('Stage A evidence is not successful at this candidate')
    marker = 'K69_STAGE_B_CLEARANCE ' + source_pin + ' ' + hashlib.sha256(data).hexdigest()
    if marker not in review_path.read_text().splitlines():
        raise RuntimeError('Stage B exact post-evidence Red clearance missing')


def main():
    global SOCKET, SESSION
    parser = argparse.ArgumentParser()
    parser.add_argument('--pin', required=True)
    parser.add_argument('--mode', choices=['codex-startup', 'codex-keepers'], required=True)
    parser.add_argument('--stage-a-result', type=Path)
    parser.add_argument('--stage-b-review', type=Path)
    parser.add_argument('--private-fixture', action='store_true')
    parser.add_argument('--private-dry-run', type=Path)
    parser.add_argument('runtime', type=Path)
    parser.add_argument('root', type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    verify_source_pin(args.pin)  # Red clearance value, before any tmux operation.
    UUID, draft_snapshot, pending_no_input, exact_turn, native_turns = load_oracles(
        Path(__file__).resolve().with_name('keeper_oracles.py'))
    runtime = args.runtime.resolve()
    if hashlib.sha256(runtime.read_bytes()).hexdigest() != EXPECTED_RUNTIME:
        raise RuntimeError('reviewed runtime changed')
    if hashlib.sha256(PROBE.read_bytes()).hexdigest() != EXPECTED_PROBE:
        raise RuntimeError('reviewed snapshot probe changed')
    if args.private_fixture:
        if args.mode != 'codex-keepers' or not os.environ.get('KS01_RUN_CAP'):
            raise RuntimeError('private fixture requires signed supervisor and keeper mode')
        lease_root = Path(subprocess.run(['/usr/bin/python3', str(GUARD), 'records'],
                                        capture_output=True, check=True).stdout.decode().strip()).resolve()
        if args.root.resolve().parent != lease_root:
            raise RuntimeError('private fixture root must be immediately inside signed records')
    else:
        verify_private_dryrun(args.pin, args.private_dry_run)
        if args.mode == 'codex-keepers':
            verify_stage_b(args.pin, args.stage_a_result, args.stage_b_review)
    root = args.root.resolve()
    root.mkdir(mode=0o700)
    name = 'e2e-k63-' + str(time.time_ns())[-6:]
    events = []
    started = time.monotonic()
    owned = set()
    created = set()
    cleanup_proven = False
    startup_deadline = None
    plan = [('codex', 'startup')] if args.mode == 'codex-startup' else [('codex', 'draft'), ('codex', 'positive')]
    window = None
    client = None
    target = None
    safe = False
    source = None
    decoy = None
    case = None
    baseline = None
    native_session = None
    expected_wire = None
    case_complete = False
    completed = set()
    cwd = Path(__file__).resolve().parents[3]
    sent = False
    socket_identity = None
    private_server_created = False
    private_server_retired = False
    operation = 'initialize'
    operation_path = str(root)
    codex_home = root / 'codex-store' if args.private_fixture else None

    def read_turns(client_name, session, directory, launch_ms):
        return native_turns(client_name, session, directory, launch_ms, codex_home=codex_home)

    def tmux(*words):
        # No subprocess timeout: timeout cleanup must never signal a PID.
        prefix = ['/usr/bin/python3', str(GUARD), 'run', 'tmux'] if args.private_fixture else [TMUX]
        result = subprocess.run([*prefix, '-S', SOCKET, *words], capture_output=True)
        if result.returncode:
            raise RuntimeError('tmux operation refused: ' + words[0])
        return result.stdout.decode().strip()

    def record(**value):
        value['elapsed_ms'] = int((time.monotonic() - started) * 1000)
        events.append(value)
        print(json.dumps(value), flush=True)

    def verify(pane=None):
        current = Path(SOCKET).stat()
        if (current.st_dev, current.st_ino) != socket_identity:
            raise RuntimeError('server socket changed')
        if tmux('display-message', '-p', '-t', window, '#{session_name}|#{window_id}|#{window_name}') != SESSION + '|' + window + '|' + name:
            raise RuntimeError('owned window changed')
        if pane is not None:
            if pane not in owned or tmux('display-message', '-p', '-t', pane, '#{session_name}|#{window_id}|#{pane_id}') != SESSION + '|' + window + '|' + pane:
                raise RuntimeError('owned pane changed')

    def kill(pane):
        verify(pane)
        tmux('kill-pane', '-t', pane)
        owned.remove(pane)
        record(event='pane-removed', pane=pane)

    def capture(pane, styled=False):
        verify(pane)
        cmd = [TMUX, '-S', SOCKET, 'capture-pane', '-p']
        if styled:
            cmd.append('-e')
        result = subprocess.run(cmd + ['-t', pane], capture_output=True, check=True)
        return result.stdout.decode().removesuffix('\n')

    def metadata(pane):
        verify(pane)
        meta = tuple(tmux('display-message', '-p', '-t', pane,
                          '#{cursor_x}|#{cursor_y}|#{pane_width}|#{pane_height}|#{pane_dead}|#{pane_in_mode}|#{pane_id}|#{pane_pid}|#{pane_tty}').split('|'))
        class BsdInfo(ctypes.Structure):
            _fields_ = [('head', ctypes.c_uint32 * 12), ('command', ctypes.c_char * 16),
                        ('name', ctypes.c_char * 32), ('tail', ctypes.c_uint32 * 6),
                        ('seconds', ctypes.c_uint64), ('micros', ctypes.c_uint64)]
        lib = ctypes.CDLL('/usr/lib/libproc.dylib')
        info = BsdInfo()
        pid = int(meta[7])
        size = lib.proc_pidinfo(pid, 3, ctypes.c_uint64(0), ctypes.byref(info), ctypes.sizeof(info))
        path = ctypes.create_string_buffer(4096)
        count = lib.proc_pidpath(pid, path, len(path))
        if size != 136 or info.head[3] != pid or info.head[1] == 5 or not info.seconds or not 0 <= info.micros < 1000000:
            raise RuntimeError('native kernel generation unavailable or changed')
        if count <= 0:
            raise RuntimeError('native kernel executable path unavailable')
        expected_image = image.resolve()
        if args.private_fixture:
            own_image = ctypes.create_string_buffer(4096)
            if lib.proc_pidpath(os.getpid(), own_image, len(own_image)) <= 0:
                raise RuntimeError('private controller executable path unavailable')
            expected_image = Path(os.fsdecode(own_image.value)).resolve()
        observed_image = Path(os.fsdecode(path.value)).resolve()
        if observed_image != expected_image:
            raise RuntimeError('native executable mismatch: expected ' + str(expected_image) + '; observed ' + str(observed_image))
        return meta + (str(info.seconds), str(info.micros), os.fsdecode(path.value))


    def snapshot(pane, expected, diagnostic=False):
        before = metadata(pane)
        screen = capture(pane, True)
        after = metadata(pane)
        reports = []
        try:
            result = draft_snapshot(screen, before, client, expected, PROBE,
                                    'snapshot: native identity/cursor/geometry raced' if before != after else None,
                                    report=reports.append)
            if diagnostic:
                observed = reports[0]
                path = root / (case_id + '-startup-fixture-' + str(len(events)) + '.json')
                path.write_text(json.dumps(observed, indent=2) + '\n')
                record(event='rust-startup-result', client=client, case=case, pane=pane,
                       accepted=True, reason=observed['reason'], sanitized_fixture=str(path),
                       native_identity=list(before[6:]), legacy_predicates=startup_predicates(screen),
                       raw_screen_retained=False)
            return result
        except ValueError as exc:
            fixture = getattr(exc, 'fixture', {'native_capture_not_retained': True})
            path = root / (case_id + '-snapshot-refusal-' + str(len(events)) + '.json')
            path.write_text(json.dumps(dict(reason=str(exc), fixture=fixture), indent=2) + '\n')
            record(event='snapshot-refused', client=client, case=case, pane=pane, accepted=False,
                   reason=exception_details(exc)['message'], exception=exception_details(exc), sanitized_fixture=str(path),
                   legacy_predicates=startup_predicates(screen) if diagnostic else None,
                   raw_screen_retained=False)
            raise


    def seed(pane, body):
        verify(pane)
        buffer = 'k63-' + uuid.uuid4().hex
        # Only synthetic text, no Enter. Never target an existing CC seat.
        tmux('set-buffer', '-b', buffer, body.decode())
        try:
            verify(pane)
            tmux('paste-buffer', '-p', '-b', buffer, '-t', pane)
        finally:
            verify(pane)
            tmux('delete-buffer', '-b', buffer)

    def inspect():
        nonlocal safe, case_complete
        safe = False
        try:
            snapshot(target, draft if baseline == 'seeded' and case == 'draft' else b'', diagnostic=True)
            if decoy:
                snapshot(decoy, decoy_draft if baseline == 'seeded' else b'', diagnostic=True)
            safe = True
        except (ValueError, RuntimeError) as exc:
            record(event='startup-not-ready', client=client, case=case,
                   reason=exception_details(exc)['message'], exception=exception_details(exc), raw_screen_retained=False)
        record(event='startup-check', client=client, case=case, pane=target,
               rust_identity_bound_composer_ready=safe, safe=safe,
               exact_seeded_composers_ready=safe if baseline == 'seeded' else None,
               raw_screen_retained=False)
        if not safe and time.monotonic() >= startup_deadline:
            raise RuntimeError('startup readiness deadline expired')
        if args.mode == 'codex-startup':
            case_complete = safe
            if safe:
                completed.add(('codex', 'startup'))
            else:
                completed.discard(('codex', 'startup'))

    error = None
    try:
        if args.private_fixture:
            SOCKET = str(root / 'server')
            SESSION = 'private-k71'
            codex_home.mkdir(mode=0o700)
            with sqlite3.connect(codex_home / 'state_5.sqlite') as db:
                db.execute('CREATE TABLE threads (id TEXT PRIMARY KEY,cwd TEXT,cli_version TEXT,created_at_ms INTEGER,history_mode TEXT)')
            with sqlite3.connect(codex_home / 'thread_history_1.sqlite') as db:
                db.execute('CREATE TABLE thread_items (thread_id TEXT,item_type TEXT,rollout_ordinal INTEGER,item_json TEXT)')
            tmux('new-session', '-d', '-s', SESSION, '-n', 'private-anchor', '/bin/sleep 300')
            private_server_created = True
        before = Path(SOCKET).stat()
        socket_identity = (before.st_dev, before.st_ino)
        # Exactly one new window for this seat. Its anchor survives every case.
        row = tmux('new-window', '-d', '-P', '-F', '#{window_id}|#{pane_id}', '-t', SESSION + ':', '-n', name, '/bin/sleep 900')
        window, anchor = row.split('|')
        owned.add(anchor)
        created.add(anchor)
        verify(anchor)
        tmux('set-window-option', '-t', window, 'automatic-rename', 'off')
        tmux('set-window-option', '-t', window, 'remain-on-exit', 'on')
        if args.private_fixture:
            tmux('set-window-option', '-t', window, 'window-size', 'manual')
            tmux('resize-window', '-t', window, '-x', '215', '-y', '57')
        record(event='window-created', session=SESSION, window=window, name=name, anchor=anchor)
        print('Mode: ' + args.mode + '; commands: launch codex startup|draft|positive, inspect, done, finish; keepers only: seed, deliver, observe', flush=True)
        while True:
            remaining = max(0, startup_deadline - time.monotonic()) if target and not sent else 300
            if not select.select([sys.stdin], [], [], min(300, remaining))[0]:
                if target and not sent:
                    inspect()  # Persist last classifier reason/fixture before expiry.
                    raise RuntimeError('startup readiness deadline expired')
                break
            command = sys.stdin.readline().strip().split()
            if not command:
                break
            operation = 'command:' + command[0]
            operation_path = str(root)
            if args.mode == 'codex-startup' and command[0] not in ('launch', 'inspect', 'done', 'finish'):
                raise RuntimeError('startup-only mode forbids all input/sender commands')
            if (len(command) == 3 and command[0] == 'launch' and target is None
                    and len(completed) < len(plan) and tuple(command[1:]) == plan[len(completed)]):
                sent = False
                case_complete = False
                baseline = None
                client, case = command[1:]
                case_id = client + '-' + case
                code_marker = '#k63_' + client + '_' + case + '_' + uuid.uuid4().hex[:8]
                payload = code_marker + ' Reply K63_OK.'
                draft = ('K63 synthetic ' + client + ' draft').encode()
                decoy_draft = ('K63 synthetic ' + client + ' decoy').encode()
                relative, digest = IMAGES[client]
                image = Path(sys.executable).resolve() if args.private_fixture else Path.home() / relative
                if args.private_fixture:
                    digest = hashlib.sha256(image.read_bytes()).hexdigest()
                if hashlib.sha256(image.read_bytes()).hexdigest() != digest:
                    raise RuntimeError('native image changed')
                launched_ms = time.time_ns() // 1000000
                native_session = str(uuid.uuid4()) if client == 'claude' or args.private_fixture else None
                def launch_native(session_id, split_args):
                    argv = [str(image)]
                    if args.private_fixture:
                        fixture_base = root / (case_id + '-' + session_id)
                        argv += [str(PRIVATE_CLIENT), str(fixture_base.with_suffix('.tsv')),
                                 str(fixture_base.with_suffix('.json')), str(fixture_base.with_suffix('.control')),
                                 str(GUARD), '--codex-harness', session_id, str(codex_home), str(cwd), str(launched_ms)]
                    elif client == 'claude':
                        project = re.sub(r'[^A-Za-z0-9]', '-', str(cwd))
                        if (Path.home() / '.claude/projects' / project / (session_id + '.jsonl')).exists():
                            raise RuntimeError('native session already exists')
                        argv += ['--session-id', session_id]
                    else:
                        argv += ['--no-daemon', '-c', 'tui.status_line=["session-id"]']
                    verify(anchor)
                    pane = tmux('split-window', *split_args, '-P', '-F', '#{pane_id}',
                                '-c', str(cwd), 'exec ' + shlex.join(argv))
                    owned.add(pane)
                    created.add(pane)
                    verify(pane)
                    return pane
                target = launch_native(native_session, ['-v', '-b', '-p', '90', '-t', anchor])
                if case == 'positive':
                    decoy = launch_native(str(uuid.uuid4()), ['-v', '-d', '-t', target])
                startup_deadline = time.monotonic() + 300
                tmux('select-pane', '-t', target)
                safe = False
                record(event='client-launched', client=client, case=case, pane=target, decoy=decoy,
                       image_sha256=digest, interactive=True, native_session=native_session)
            elif command == ['inspect'] and target:
                inspect()
            elif command == ['seed'] and target and safe and not sent and baseline is None:
                # Agent waits for inspect readiness; seed completion is proved by
                # the subsequent snapshot, never a stabilization sleep.
                snapshot(target, b'')
                if case == 'draft':
                    seed(target, draft)
                else:
                    snapshot(decoy, b'')
                    seed(decoy, decoy_draft)
                baseline = 'seeded'
                safe = False
                record(event='synthetic-draft-seeded', client=client, case=case)
            elif command == ['deliver'] and target and safe and source is None and not sent and baseline == 'seeded':
                verify_source_pin(args.pin)
                inspect()
                if not safe:
                    raise RuntimeError('unsafe screen; no sender input')
                before_target = snapshot(target, draft if case == 'draft' else b'')
                before_decoy = snapshot(decoy, decoy_draft) if decoy else None
                if decoy and code_marker in capture(decoy):
                    raise RuntimeError('decoy code not absent at baseline')
                operation = 'deliver.native-session-baseline'
                operation_path = str((codex_home if codex_home else Path.home() / '.codex') / 'state_5.sqlite')
                if client == 'codex':
                    ids = set(re.findall(UUID, capture(target)))
                    if len(ids) == 1:
                        native_session = ids.pop()
                        record(event='native-session-baseline-query', client=client, case=case,
                               native_session=native_session, database_path=exception_details(OSError(0, '', operation_path))['missing_path'])
                        if read_turns(client, native_session, cwd, launched_ms):
                            raise RuntimeError('fresh session has prior user turns')
                    elif ids:
                        raise RuntimeError('native session ambiguous')
                elif case == 'positive':
                    # Newly allocated Claude UUID/path checked absent at launch.
                    try:
                        if read_turns(client, native_session, cwd, launched_ms):
                            raise RuntimeError('fresh session has prior user turns')
                    except FileNotFoundError:
                        pass
                operation = 'deliver.sender'
                operation_path = str(root / (case_id + '-sender.json'))
                verify(anchor)
                store = root / (case_id + '-archive')
                overrides = dict(ANGELSTAR_RELAY_SOCKET=SOCKET, ANGELSTAR_RELAY_STORE=str(store),
                                 ANGELSTAR_RELAY_WAIT_MS='1000' if case == 'draft' else '12000',
                                 CC_MSG_SESSION=SESSION, CC_MSG_WINDOW=name, CC_MSG_PANE=target)
                result_path = root / (case_id + '-sender.json')
                gate = root / (case_id + '-go')
                # Source waits for an explicit event. Its actual tmux identity is
                # independently measured before the sole sender invocation.
                sender_command = ([str(PROBE), '--exact', 'runtime::tests::harness_cli_probe', '--ignored', '--nocapture']
                                  if args.private_fixture else [str(runtime), '--surface', 'cc-msg', '--', payload])
                request = dict(args=['--', payload], fixture=str(root / (case_id + '-' + native_session + '.json'))) if args.private_fixture else None
                worker = ("from pathlib import Path\n"
                          + 'gate=Path(' + repr(str(gate)) + ')\n'
                          + 'deadline=time.monotonic()+60\n'
                          + 'while not gate.exists():\n'
                          + ' if time.monotonic()>deadline: raise RuntimeError("sender gate deadline expired")\n'
                          + ' time.sleep(.05)\n'
                          + 'e={k:v for k,v in os.environ.items() if (k!="KS01_RUN_CAP" or ' + repr(args.private_fixture) + ') and not k.startswith("ANGELSTAR_")}\n'
                          + 'e.update(' + repr(overrides) + ')\n'
                          + 'r=subprocess.run(' + repr(sender_command) + ',env=e,input='
                          + repr(json.dumps(request).encode() if request else None)
                          + ',stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n'
                          + 'out={"exit":r.returncode}\n')
                wrapper = 'import json,os,subprocess,time\ntry:\n' + ''.join(' '+line+'\n' for line in worker.splitlines())
                wrapper += ('except Exception as exc:\n'
                            + ' out={"exit":None,"exception":{"exception_type":type(exc).__name__,"message":str(exc).replace(os.path.expanduser("~"),"$HOME"),"missing_path":str(getattr(exc,"filename",None)).replace(os.path.expanduser("~"),"$HOME")}}\n'
                            + 'open(' + repr(str(result_path)) + ',"x").write(json.dumps(out))\n')
                source = tmux('split-window', '-h', '-d', '-P', '-F', '#{pane_id}', '-t', anchor,
                              'exec /usr/bin/python3 -c ' + shlex.quote(wrapper))
                owned.add(source)
                created.add(source)
                verify(source)
                source_session, source_window, source_name, source_pane = tmux(
                    'display-message', '-p', '-t', source,
                    '#{session_name}|#{window_id}|#{window_name}|#{pane_id}').split('|')
                if (source_session, source_window, source_name, source_pane) != (SESSION, window, name, source):
                    raise RuntimeError('source identity unproved')
                label = source_name + ' (' + source_session + ':' + source_name + ')'
                expected_wire = (label + ': ' + payload).encode()
                if len(expected_wire) >= int(before_target[0][2]) - 10:
                    raise RuntimeError('wire would use archive fallback')
                # Splitting the anchor must not have changed target/decoy geometry.
                if snapshot(target, draft if case == 'draft' else b'') != before_target:
                    raise RuntimeError('target baseline changed before sender')
                if decoy and snapshot(decoy, decoy_draft) != before_decoy:
                    raise RuntimeError('decoy baseline changed before sender')
                native_deadline = time.monotonic() + 90
                gate.touch(exist_ok=False)
                sent = True
                record(event='sender-launched', client=client, case=case, source=source, target=target,
                       independent_source_identity=[source_session, source_window, source_name, source_pane],
                       expected_wire_length=len(expected_wire), native_session=native_session)
            elif command == ['observe'] and source:
                verify(target)
                verify(source)
                path = root / (case_id + '-sender.json')
                if path.exists():
                    result = json.loads(path.read_text())
                    if result.get('exception'):
                        record(event='sender-wrapper-exception', **result['exception'])
                        raise RuntimeError('sender wrapper failed; see exception record')
                    attempts = json.loads((store / 'ledger.json').read_text())['attempts']
                    histories = [[step['state'] for step in attempt['history']] for attempt in attempts]
                    if case == 'draft':
                        after = snapshot(target, draft)
                        unchanged = before_target == after
                        proof = unchanged and pending_no_input(result['exit'], histories)
                        record(event='draft-oracle', client=client, case=case, exit=result['exit'],
                               histories=histories, exact_native_draft_unchanged=unchanged,
                               draft_length=len(draft), native_identity_cursor_geometry_unchanged=before_target[0] == after[0],
                               keeper_proven=proof, bodies_or_body_hashes_retained=False)
                    else:
                        after_decoy = snapshot(decoy, decoy_draft)
                        decoy_unchanged = before_decoy == after_decoy
                        decoy_code_absent = code_marker not in capture(decoy)
                        if metadata(target)[6:] != before_target[0][6:]:
                            raise RuntimeError('native target identity changed')
                        if time.monotonic() > native_deadline:
                            raise RuntimeError('native user turn deadline expired')
                        if client == 'codex' and native_session is None:
                            ids = set(re.findall(UUID, capture(target)))
                            if not ids:
                                record(event='native-session-pending', client=client, case=case)
                                continue
                            if len(ids) != 1:
                                raise RuntimeError('native session unproved')
                            native_session = ids.pop()
                        try:
                            turns = read_turns(client, native_session, cwd, launched_ms)
                        except FileNotFoundError:
                            turns = []
                        if not turns:
                            record(event='native-user-turn-pending', client=client, case=case)
                            continue
                        turn_equal = exact_turn(turns, expected_wire)
                        proof = (result['exit'] == 0 and len(histories) == 1
                                 and histories[0][-1] == 'submitted' and turn_equal
                                 and decoy_unchanged and decoy_code_absent)
                        record(event='positive-oracle', client=client, case=case, exit=result['exit'],
                               histories=histories, native_session=native_session, native_turn_count=len(turns),
                               full_native_user_turn_exact=turn_equal, expected_wire_length=len(expected_wire),
                               exact_decoy_unchanged=decoy_unchanged, decoy_code_absent=decoy_code_absent,
                               decoy_length=len(decoy_draft), keeper_proven=proof, bodies_or_body_hashes_retained=False)
                    if not proof:
                        raise RuntimeError('keeper oracle unproved')
                    kill(source)
                    source = None
                    case_complete = True
                    completed.add((client, case))
                else:
                    record(event='sender-pending', client=client, case=case)
            elif command == ['done'] and target and source is None and case_complete:
                if decoy:
                    kill(decoy)
                    decoy = None
                kill(target)
                target = None
                baseline = None
                safe = False
            elif command == ['finish']:
                if completed != set(plan):
                    raise RuntimeError('required stage cases incomplete')
                break
            else:
                record(event='command-refused')
    except Exception as exc:
        error = type(exc).__name__
        record(event='hold', error=error, operation=operation, operation_path=exception_details(OSError(0, '', operation_path))['missing_path'], **exception_details(exc))
    finally:
        if completed != set(plan) and error is None:
            error = 'required-stage-cases-incomplete'
        # Only exact IDs created above, revalidated in the same owned window.
        for pane in list(owned):
            if pane != locals().get('anchor'):
                try:
                    kill(pane)
                except Exception as exc:
                    record(event='cleanup-exception', pane=pane, **exception_details(exc))
                    error = 'owned-pane-cleanup-unproved'
        if window is not None:
            try:
                verify()
                if owned != {anchor}:
                    raise RuntimeError('pane cleanup incomplete')
                # Kill the last owned pane only at final window removal; killing
                # it removes the window atomically, never selecting another target.
                kill(anchor)
                record(event='window-removed', window=window)
                current = Path(SOCKET).stat()
                if (current.st_dev, current.st_ino) != socket_identity:
                    raise RuntimeError('server socket changed after cleanup')
                rows = tmux('list-panes', '-a', '-F', '#{pane_id}|#{window_id}').splitlines()
                cleanup_proven = all(row.split('|')[0] not in created and row.split('|')[1] != window for row in rows)
                if not cleanup_proven:
                    raise RuntimeError('owned resource absence unproved')
                record(event='owned-resource-absence-proved', window=window, panes=sorted(created))
            except Exception as exc:
                record(event='cleanup-exception', window=window, **exception_details(exc))
                error = 'owned-window-cleanup-unproved'
        if private_server_created:
            try:
                subprocess.run(['/usr/bin/python3', str(GUARD), 'stop', 'tmux', '-S', SOCKET],
                               capture_output=True, check=True)
                private_server_retired = True
                record(event='signed-private-server-retired')
            except Exception as exc:
                record(event='private-cleanup-exception', **exception_details(exc))
                error = 'private-server-retirement-unproved'
        (root / 'result.json').write_text(json.dumps(dict(mode=args.mode, source_pin=args.pin, private_fixture=args.private_fixture,
            private_server_retired=private_server_retired, controller_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), runtime_sha256=EXPECTED_RUNTIME,
            probe_sha256=EXPECTED_PROBE, completed=sorted(completed), readiness_proven=('codex', 'startup') in completed,
            cleanup_proven=cleanup_proven, events=events, error=error, acceptance='HOLD until Red evidence review'), indent=2) + '\n')
    return 1 if error else 0


if __name__ == '__main__':
    try:
        exit_code = main()
    except Exception as exc:
        print(json.dumps(dict(event='admission-exception', **exception_details(exc))), file=sys.stderr)
        exit_code = 1
    raise SystemExit(exit_code)
