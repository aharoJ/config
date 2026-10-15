#!/usr/bin/python3
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shlex
import stat
import subprocess
import sys
import time

TMUX = '/opt/homebrew/bin/tmux'
SESSION = 'config(tmux-to-rust)'
SURFACES = ('relay', 'cc-msg', 'codex-send', 'codex-send-to')
PINS = {
    'claude296': ('2.1.296', 'c9b5341637becbd423ddffc5b254afb645682a3868cb708bbc6cc0e7bb419937'),
    'claude299': ('2.1.299', 'ba5ab7b8c195fa03ab8d5bf3915c76153b576a2c40e79a5c46e265e7ed9744b3'),
    'codex': ('0.162.1', '74c6a6d263f40d65f99c27a815275f5b4ed0bcc2baecc396b4cf3255498bdfc0'),
}


class Refused(RuntimeError):
    pass


def digest(path):
    with Path(path).open('rb') as stream:
        def stamp(value):
            return (value.st_dev, value.st_ino, value.st_mode, value.st_uid, value.st_size, value.st_mtime_ns, value.st_ctime_ns)
        before = stamp(os.fstat(stream.fileno()))
        value = hashlib.file_digest(stream, 'sha256').hexdigest() if hasattr(hashlib, 'file_digest') else hashlib.sha256(stream.read()).hexdigest()
        if before != stamp(os.fstat(stream.fileno())) or before != stamp(Path(path).stat()):
            raise Refused('file changed while hashing')
        return value


def atomic_json(path, value):
    path = Path(path)
    temporary = path.with_name(path.name + '.pending')
    with temporary.open('x') as stream:
        os.chmod(temporary, 0o600)
        json.dump(value, stream, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def refusal_proof(sent, ledger, expected_peer):
    announcement = json.loads(sent['stdout'])
    if sent['exit'] != 1 or announcement.get('state') != 'terminal-no-input' or announcement.get('submission') != 'unproved' or announcement.get('receipt') != 'unproved':
        raise Refused('expected incompatible-target no-input refusal missing')
    attempts = [a for a in ledger['attempts'] if a['id'] == announcement['attempt']]
    if len(attempts) != 1 or [h['state'] for h in attempts[0]['history']] != ['pending-no-input', 'terminal-no-input'] or attempts[0]['archive'] != announcement['archive']:
        raise Refused('no-input ledger proof missing')
    if attempts[0]['peer'] != expected_peer or announcement.get('peer') != expected_peer:
        raise Refused('announcement and ledger peer identity mismatch')
    return announcement


class BsdInfo(ctypes.Structure):
    _fields_ = [('head', ctypes.c_uint32 * 12), ('command', ctypes.c_char * 16),
                ('name', ctypes.c_char * 32), ('tail', ctypes.c_uint32 * 6),
                ('seconds', ctypes.c_uint64), ('micros', ctypes.c_uint64)]


class Kernel:
    def __init__(self):
        self.lib = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
        self.lib.proc_pidinfo.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_int]
        self.lib.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]

    def identity(self, pid):
        info = BsdInfo()
        count = self.lib.proc_pidinfo(pid, 3, 0, ctypes.byref(info), ctypes.sizeof(info))
        if count != 136 or info.head[3] != pid or info.head[1] == 5 or not info.seconds or info.micros >= 1000000:
            raise Refused('kernel process identity unavailable')
        return [pid, info.seconds, info.micros]

    def path(self, pid):
        buffer = ctypes.create_string_buffer(4096)
        if self.lib.proc_pidpath(pid, buffer, len(buffer)) <= 0:
            raise Refused('kernel executable path unavailable')
        return str(Path(os.fsdecode(buffer.value)).resolve(strict=True))


class Calls:
    def __init__(self, seconds=2):
        self.seconds = seconds
        self.pending = None
        self.frozen = False

    def run(self, argv, data=None, env=None):
        if self.frozen:
            raise Refused('previous command outcome unresolved; no further calls')
        child = subprocess.Popen(argv, stdin=subprocess.PIPE if data is not None else subprocess.DEVNULL,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
        self.pending = child
        output = [bytearray(), bytearray()]
        selector = selectors.DefaultSelector()
        for index, pipe in enumerate((child.stdout, child.stderr)):
            os.set_blocking(pipe.fileno(), False)
            selector.register(pipe, selectors.EVENT_READ, index)
        remaining = memoryview(data or b'')
        if data is not None:
            if remaining:
                os.set_blocking(child.stdin.fileno(), False)
                selector.register(child.stdin, selectors.EVENT_WRITE, 2)
            else:
                child.stdin.close()
        deadline = time.monotonic() + self.seconds
        try:
            while selector.get_map() or child.poll() is None:
                if time.monotonic() >= deadline:
                    raise Refused('command deadline; outcome unresolved; pid=' + str(child.pid))
                for key, _ in selector.select(min(.01, max(0, deadline - time.monotonic()))):
                    if key.data == 2:
                        count = os.write(key.fd, remaining[:4096])
                        remaining = remaining[count:]
                        if not remaining:
                            selector.unregister(key.fileobj)
                            key.fileobj.close()
                    else:
                        block = os.read(key.fd, 65536)
                        if not block:
                            selector.unregister(key.fileobj)
                            key.fileobj.close()
                        else:
                            output[key.data].extend(block)
                            if len(output[key.data]) > 1024 * 1024:
                                raise Refused('command output bound; outcome unresolved')
            self.pending = None
            return subprocess.CompletedProcess(argv, child.returncode, bytes(output[0]), bytes(output[1]))
        except BaseException:
            self.frozen = True
            raise
        finally:
            selector.close()


def parse_panes(raw):
    result = {}
    for line in raw.decode().splitlines():
        values = line.split('|')
        if len(values) != 8:
            raise Refused('unexpected pane inventory')
        session, name, window, title, pane, pid, dead, command = values
        if not re.fullmatch(r'\$\d+', session) or not re.fullmatch(r'@\d+', window) or not re.fullmatch(r'%\d+', pane) or pane in result or not pid.isdecimal() or dead != '0':
            raise Refused('ambiguous or dead pane inventory')
        result[pane] = dict(session=session, name=name, window=window, title=title, pid=int(pid), command=command)
    return result


def validate_owned(panes, window, owned, kernel, allow_missing=False):
    current = {pane: value for pane, value in panes.items() if value['window'] == window}
    if set(current) - set(owned) or (not allow_missing and set(current) != set(owned)):
        raise Refused('owned window membership changed')
    for pane, value in current.items():
        expected = owned[pane]
        if value['session'] != expected['session'] or value['name'] != SESSION or value['title'] != expected['title'] or value['pid'] != expected['identity'][0] or kernel.identity(value['pid']) != expected['identity']:
            raise Refused('owned pane identity changed')
    return current


def package_inventory(root):
    root = Path(root)
    result = {}
    for path in sorted(root.rglob('*')):
        relative = str(path.relative_to(root))
        if path.is_symlink():
            if not path.resolve(strict=True).is_relative_to(root):
                raise Refused('package link escapes package')
            result[relative] = dict(link=os.readlink(path))
        elif path.is_file():
            result[relative] = dict(sha256=digest(path))
        elif not path.is_dir():
            raise Refused('package has special file')
    return result


def native_launch_plan(client, image, native_session=None):
    path = Path(image)
    value = digest(path)
    if client == 'claude':
        profiles = [version for version, expected in PINS.values() if expected == value and version.startswith('2.')]
        if len(profiles) != 1 or path.name != profiles[0] or not re.fullmatch(r'[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}', native_session or ''):
            raise Refused('exact supported Claude image and fresh session required')
        return [str(path), '--session-id', native_session]
    if client == 'codex' and value == PINS['codex'][1] and path.name == 'codex':
        return [str(path), '--no-daemon', '-c', 'tui.status_line=["session-id"]']
    raise Refused('exact supported native image required')


def live_preflight():
    calls = Calls()
    kernel = Kernel()
    socket = '/private/tmp/tmux-%d/default' % os.geteuid()
    def observe(args):
        result = calls.run([TMUX, '-N', '-S', socket, *args])
        if result.returncode:
            raise Refused('read-only preflight observation failed')
        return result.stdout
    server, session_id, observed_socket, version = observe(['display-message', '-p', '-t', '=' + SESSION, '#{pid}|#{session_id}|#{socket_path}|#{version}']).decode().strip().split('|')
    if observed_socket != socket or version != '3.7c':
        raise Refused('unexpected socket or tmux version')
    server_identity = kernel.identity(int(server))
    info = Path(socket).lstat()
    panes = parse_panes(observe(['list-panes', '-s', '-t', '=' + SESSION, '-F', '#{session_id}|#{session_name}|#{window_id}|#{window_name}|#{pane_id}|#{pane_pid}|#{pane_dead}|#{pane_current_command}']))
    listed = calls.run(['/bin/ps', '-axo', 'pid=,ppid='])
    if listed.returncode:
        raise Refused('process ancestry observation failed')
    processes = [tuple(map(int, row.split())) for row in listed.stdout.decode().splitlines()]
    records = []
    for pane, row in panes.items():
        root_identity = kernel.identity(row['pid'])
        descendants = {row['pid']}
        for _ in range(8):
            newer = descendants | {pid for pid, parent in processes if parent in descendants}
            if len(newer) > 64:
                raise Refused('pane ancestry ambiguous')
            if newer == descendants:
                break
            descendants = newer
        images = []
        for pid in sorted(descendants):
            try:
                identity = kernel.identity(pid)
                path = Path(kernel.path(pid))
            except Refused:
                continue
            if '/claude/versions/' not in str(path) and path.name != 'codex':
                continue
            image_digest = digest(path)
            if kernel.identity(pid) != identity or kernel.path(pid) != str(path):
                raise Refused('native process changed during observation')
            profiles = [key for key, (_, expected) in PINS.items() if expected == image_digest]
            images.append(dict(identity=identity, path=str(path), size=path.stat().st_size, sha256=image_digest,
                               profile=profiles[0] if len(profiles) == 1 else None,
                               version=PINS[profiles[0]][0] if len(profiles) == 1 else path.name,
                               supported=len(profiles) == 1))
        if kernel.identity(row['pid']) != root_identity:
            raise Refused('pane owner changed during observation')
        records.append(dict(pane=pane, route=row, pane_identity=root_identity, native_images=images))
    public_claude = Path.home() / '.local/bin/claude'
    codex_package = Path.home() / '.local/share/fnm/node-versions/v22.19.0/installation/lib/node_modules/@openai/codex/package.json'
    if kernel.identity(int(server)) != server_identity or (info.st_dev, info.st_ino) != (Path(socket).lstat().st_dev, Path(socket).lstat().st_ino):
        raise Refused('server changed during preflight')
    return dict(schema='relay-native-preflight-v1', observed_at_ns=time.time_ns(), uid=os.geteuid(), socket=socket,
                socket_identity=[info.st_dev, info.st_ino], server=server_identity, server_path=kernel.path(int(server)),
                session=SESSION, session_id=session_id, tmux_version=version, panes=records,
                public_claude=dict(path=str(public_claude), resolved=str(public_claude.resolve(strict=True)), sha256=digest(public_claude)),
                codex_package=dict(path=str(codex_package), version=json.loads(codex_package.read_bytes())['version']),
                native_launched=False, input_sent=False, server_mutated=False)


def validate_approval(value, home=None, active=False):
    home = Path.home() if home is None else Path(home)
    if value.get('schema') != 'relay-cutover-smoke-v1' or value.get('scope') != 'owned-window-refusal':
        raise Refused('only refusal smoke is implemented; native matrix requires a fresh driver review')
    if value.get('driver_sha256') != digest(__file__) or value.get('uid') != os.geteuid():
        raise Refused('driver or user pin mismatch')
    if value.get('socket') != '/private/tmp/tmux-%d/default' % os.geteuid() or value.get('session') != SESSION:
        raise Refused('exact server and session required')
    if not re.fullmatch(r'\$\d+', value.get('session_id', '')) or not isinstance(value.get('server'), list) or len(value['server']) != 3 or any(type(n) is not int or n < 0 for n in value['server']) or value['server'][0] == 0 or value['server'][1] == 0 or value['server'][2] >= 1000000:
        raise Refused('exact kernel server generation required')
    if not isinstance(value.get('socket_identity'), list) or len(value['socket_identity']) != 2 or any(type(n) is not int or n < 0 for n in value['socket_identity']) or value['socket_identity'][1] == 0:
        raise Refused('exact socket device and inode required')
    if not re.fullmatch(r's6x-smoke-[a-f0-9]{12}', value.get('window_name', '')):
        raise Refused('invalid owned window name')
    root = Path(value['root'])
    if root != home / 'desk/tmp/relay' / value['window_name'] or root.exists() != active or root.is_symlink() or root.parent.resolve() != root.parent:
        raise Refused('fresh canonical smoke directory required')
    if active and (not root.is_dir() or root.stat().st_uid != os.geteuid() or stat.S_IMODE(root.stat().st_mode) != 0o700):
        raise Refused('active smoke root is not private')
    if value.get('entries') != {name: str(home / '.local/bin' / name) for name in SURFACES}:
        raise Refused('exact four public entry paths required')
    package = Path(value['package'])
    if package.parent != home / 'desk/relay-packages' or not re.fullmatch(r'rust-[a-f0-9]{40}', package.name) or package.resolve(strict=True) != package:
        raise Refused('immutable package path required')
    if package_inventory(package) != value.get('package_inventory'):
        raise Refused('complete package inventory mismatch')
    for entry in value['entries'].values():
        if not Path(entry).resolve(strict=True).is_relative_to(package):
            raise Refused('public entry does not resolve into approved package')
    store = Path(value['store'])
    if store != home / 'desk/relay-store-v1' or store.resolve(strict=True) != store:
        raise Refused('installed store pin mismatch')
    return value


class Driver:
    def __init__(self, approval, calls=None, kernel=None):
        self.approval = approval
        self.calls = calls or Calls()
        self.kernel = kernel or Kernel()
        self.window = None
        self.owned = {}
        self.root = Path(approval['root'])

    def command(self, args):
        value = self.approval
        socket = Path(value['socket']).lstat()
        if not stat.S_ISSOCK(socket.st_mode) or socket.st_uid != value['uid'] or [socket.st_dev, socket.st_ino] != value['socket_identity'] or self.kernel.identity(value['server'][0]) != value['server']:
            self.calls.frozen = True
            raise Refused('server identity changed; no more calls')
        result = self.calls.run([TMUX, '-N', '-S', value['socket'], *args])
        if result.returncode:
            self.calls.frozen = True
            raise Refused('tmux command failed; no more calls')
        return result.stdout

    def panes(self):
        return parse_panes(self.command(['list-panes', '-s', '-t', '=' + SESSION, '-F', '#{session_id}|#{session_name}|#{window_id}|#{window_name}|#{pane_id}|#{pane_pid}|#{pane_dead}|#{pane_current_command}']))

    def checkpoint(self):
        atomic_json(self.root / 'resources.json', dict(window=self.window, owned=self.owned))

    def adopt(self, raw, previous):
        window, pane = raw.decode().strip().split('|')
        panes = self.panes()
        if pane in previous or (self.window is not None and window != self.window) or (self.window is None and any(p['window'] == window for p in previous.values())):
            raise Refused('new resource is not fresh')
        row = panes[pane]
        if row['window'] != window or row['session'] != self.approval['session_id'] or row['name'] != SESSION or row['title'] != self.approval['window_name']:
            raise Refused('new resource route mismatch')
        self.window = window
        self.owned[pane] = dict(session=row['session'], title=row['title'], identity=self.kernel.identity(row['pid']))
        self.checkpoint()
        validate_owned(panes, self.window, self.owned, self.kernel)
        return pane

    def split(self, command):
        previous = self.panes()
        current = validate_owned(previous, self.window, self.owned, self.kernel)
        raw = self.mutation(['split-window', '-d', '-t', self.window, '-P', '-F', '#{window_id}|#{pane_id}', '-c', str(self.root), command], next(iter(current)), len(current))
        return self.adopt(raw, previous)

    def mutation(self, args, pane, count):
        expected = self.owned[pane]
        pairs = [('pid', self.approval['server'][0]), ('session_id', expected['session']),
                 ('window_id', self.window), ('window_name', expected['title']),
                 ('pane_id', pane), ('pane_pid', expected['identity'][0]), ('window_panes', count)]
        condition = '#{&&:' + ','.join('#{==:#{%s},%s}' % pair for pair in pairs) + '}'
        output = self.command(['if-shell', '-F', '-t', pane, condition, shlex.join(args), 'display-message -p s6x-mutation-refused'])
        if output.strip() == b's6x-mutation-refused':
            raise Refused('atomic owned-resource guard refused')
        return output

    def snapshot(self, pane):
        validate_owned(self.panes(), self.window, self.owned, self.kernel)
        args = ['display-message', '-p', '-t', pane, '#{cursor_x}|#{cursor_y}|#{pane_width}|#{pane_height}|#{pane_dead}|#{pane_in_mode}']
        before = self.command(args)
        capture = self.command(['capture-pane', '-p', '-e', '-t', pane])
        if before != self.command(args):
            raise Refused('owned snapshot changed during capture')
        return before, capture

    def cleanup(self):
        for pane in list(self.owned)[1:]:
            current = validate_owned(self.panes(), self.window, self.owned, self.kernel, True)
            if pane in current:
                self.mutation(['kill-pane', '-t', pane], pane, len(current))
            del self.owned[pane]
            self.checkpoint()
        current = validate_owned(self.panes(), self.window, self.owned, self.kernel, True)
        if current:
            self.mutation(['kill-window', '-t', self.window], next(iter(current)), 1)
        if any(p['window'] == self.window for p in self.panes().values()):
            raise Refused('owned window retirement unproved')

    def run(self):
        value = self.approval
        previous = self.panes()
        if any(p['title'] == value['window_name'] for p in previous.values()):
            raise Refused('window name already exists')
        self.root.mkdir(mode=0o700)
        result = dict(scope=value['scope'], native_launched=False, success=False, cleanup_proven=False)
        try:
            for entry in value['entries'].values():
                checked = self.calls.run([entry, '--help'])
                if checked.returncode:
                    raise Refused('public help failed')
            anchor = self.adopt(self.command(['new-window', '-d', '-t', '=' + SESSION + ':', '-n', value['window_name'], '-P', '-F', '#{window_id}|#{pane_id}', '-c', str(self.root), '/bin/sleep 900']), previous)
            target = self.split('/bin/sleep 900')
            decoy = self.split('/bin/sleep 900')
            source = self.split(shlex.join(['/usr/bin/python3', '-B', str(Path(__file__).resolve()), '_sender', str(self.root)]))
            validate_owned(self.panes(), self.window, self.owned, self.kernel)
            target_before = self.snapshot(target)
            decoy_before = self.snapshot(decoy)
            request = dict(approval=value, source=source, target=target, window=self.window, owned=self.owned)
            atomic_json(self.root / 'request.json', request)
            deadline = time.monotonic() + 10
            while not self.root.joinpath('sender-result.json').exists():
                if time.monotonic() >= deadline:
                    self.calls.frozen = True
                    raise Refused('sender outcome unresolved; no further server calls')
                time.sleep(.01)
            sent = json.loads(self.root.joinpath('sender-result.json').read_text())
            if not sent.get('closed'):
                self.calls.frozen = True
                raise Refused('sender child unresolved; preserve owned resources')
            ledger = json.loads(Path(value['store'], 'ledger.json').read_bytes())
            expected_peer = dict(session=int(value['session_id'][1:]), window=int(self.window[1:]), pane=int(target[1:]),
                                 socket_device=value['socket_identity'][0], socket_inode=value['socket_identity'][1],
                                 server_generation=value['server'][1] * 1000000 + value['server'][2],
                                 pane_generation=self.owned[target]['identity'][1] * 1000000 + self.owned[target]['identity'][2])
            announcement = refusal_proof(sent, ledger, expected_peer)
            if target_before != self.snapshot(target) or decoy_before != self.snapshot(decoy):
                raise Refused('owned target or decoy changed')
            validate_owned(self.panes(), self.window, self.owned, self.kernel)
            result.update(success=True, attempt=announcement['attempt'], archive=announcement['archive'], anchor=anchor, source=source, target=target, decoy=decoy, target_unchanged=True, decoy_unchanged=True)
        except BaseException as error:
            self.calls.frozen = True
            result['error'] = type(error).__name__ + ': ' + str(error)
            raise
        finally:
            if self.window is not None and not self.calls.frozen:
                try:
                    self.cleanup()
                    result['cleanup_proven'] = True
                except BaseException as error:
                    self.calls.frozen = True
                    result['cleanup_error'] = type(error).__name__ + ': ' + str(error)
                    result['success'] = False
            result['calls_frozen'] = self.calls.frozen
            atomic_json(self.root / 'result.json', result)
        if not result['success'] or not result['cleanup_proven']:
            raise Refused('smoke or cleanup unproved')
        return result


def sender(root):
    root = Path(root)
    deadline = time.monotonic() + 10
    while not root.joinpath('request.json').exists():
        if time.monotonic() >= deadline:
            raise Refused('sender request absent')
        time.sleep(.01)
    request = json.loads(root.joinpath('request.json').read_text())
    value = request['approval']
    validate_approval(value, active=True)
    if value['driver_sha256'] != digest(__file__) or os.environ.get('TMUX_PANE') != request['source']:
        raise Refused('sender identity mismatch')
    driver = Driver(value)
    driver.window = request['window']
    driver.owned = request['owned']
    validate_owned(driver.panes(), driver.window, driver.owned, driver.kernel)
    env = dict(os.environ, CC_MSG_SESSION=SESSION, CC_MSG_WINDOW=value['window_name'], CC_MSG_PANE=request['target'], ANGELSTAR_RELAY_WAIT_MS='1000')
    outcome = dict(closed=False)
    try:
        sent = driver.calls.run([value['entries']['cc-msg'], '#s6x-smoke Synthetic routing refusal check.'], env=env)
        outcome = dict(closed=True, exit=sent.returncode, stdout=sent.stdout.decode(), stderr=sent.stderr.decode())
    finally:
        atomic_json(root / 'sender-result.json', outcome)
    while time.monotonic() < deadline + 20:
        time.sleep(.05)


def main():
    if len(sys.argv) == 3 and sys.argv[1] == 'preflight':
        destination = Path(sys.argv[2])
        if not destination.resolve().is_relative_to(Path.home() / 'desk'):
            raise Refused('preflight evidence must be under desk')
        evidence = live_preflight()
        destination.write_text(json.dumps(evidence, indent=2) + '\n')
        print(json.dumps(dict(evidence=str(destination), native_launched=False, input_sent=False)))
        return
    if len(sys.argv) == 3 and sys.argv[1] == '_sender':
        sender(sys.argv[2])
        return
    parser = argparse.ArgumentParser()
    parser.add_argument('--approval', type=Path, required=True)
    parser.add_argument('--approval-sha256', required=True)
    parser.add_argument('--execute-refusal', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-f0-9]{64}', args.approval_sha256) or digest(args.approval) != args.approval_sha256:
        raise Refused('external approval pin mismatch')
    value = validate_approval(json.loads(args.approval.read_bytes()))
    if not args.execute_refusal:
        print(json.dumps(dict(validated=True, native_matrix_implemented=False, execution_requested=False)))
        return
    os.umask(0o077)
    print(json.dumps(Driver(value).run()))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('smoke refused: ' + str(error), file=sys.stderr)
        sys.exit(1)
