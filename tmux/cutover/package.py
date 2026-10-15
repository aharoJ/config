#!/usr/bin/python3
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys

BASELINE = '5b2dbc0deb26f44b1ccf2981ed35b521f9c01d63'
DESK = Path.home() / 'desk'
SURFACES = {'relay': 'relay', 'cc-msg': 'cc-msg.sh', 'codex-send': 'codex-send', 'codex-send-to': 'codex-send-to'}
RUST_PATHS = ['tmux/rust/Cargo.toml', 'tmux/rust/Cargo.lock', 'tmux/rust/src', 'tmux/tests/delivery_guard.py', 'tmux/tests/cleanup_guard.py', 'tmux/tools/test-server-cleanup', *['tmux/tools/' + name for name in SURFACES.values()], 'tmux/cutover/launch.py']
TOOLCHAIN = Path.home() / '.rustup/toolchains/stable-aarch64-apple-darwin/bin'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def canonical(path):
    path = Path(path)
    require(path.is_absolute() and str(path) == os.path.normpath(str(path)) and path.resolve() == path, 'noncanonical path: ' + str(path))
    return path


def desk_path(path):
    path = canonical(path)
    require(DESK in path.parents, 'writes must remain under desk: ' + str(path))
    return path


def regular(path):
    info = Path(path).lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_uid == os.geteuid() and info.st_nlink == 1, 'unsafe regular file: ' + str(path))
    return info


def git(repo, *args):
    return subprocess.check_output(['git', '--no-optional-locks', '-C', str(repo), *args])


def pin(repo, commit):
    require(re.fullmatch('[0-9a-f]{40}', commit) is not None, 'full commit required')
    require(git(repo, 'rev-parse', commit + '^{commit}').decode().strip() == commit, 'source commit mismatch')


def source_tree(repo, commit, paths):
    pin(repo, commit)
    result = []
    for row in git(repo, 'ls-tree', '-rz', commit, '--', *paths).split(b'\0'):
        if not row:
            continue
        head, name = row.split(b'\t', 1)
        mode, kind, oid = head.decode().split()
        name = name.decode()
        require(kind == 'blob' and mode in ('100644', '100755', '120000'), 'unsupported Git entry')
        require(not Path(name).is_absolute() and '..' not in Path(name).parts, 'unsafe source path')
        data = git(repo, 'cat-file', 'blob', oid)
        result.append(dict(path=name, gitmode=mode, oid=oid, sha256=digest(data), data=data))
    require(result, 'empty source tree')
    return result


def working_tree_snapshot(repo, commit):
    require(git(repo, 'rev-parse', 'HEAD').decode().strip() == commit, 'baseline HEAD mismatch')
    before = git(repo, 'status', '--porcelain', '--untracked-files=no', '--', 'tmux/tools').decode()
    rows = source_tree(repo, commit, ['tmux/tools'])
    identities = []
    for row in rows:
        path = repo / row['path']
        info = path.lstat()
        require(info.st_uid == os.geteuid() and info.st_nlink == 1, 'baseline owner or hardlink refused')
        require(stat.S_ISLNK(info.st_mode) if row['gitmode'] == '120000' else stat.S_ISREG(info.st_mode), 'baseline source type changed')
        identity = lambda value: (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns, value.st_ctime_ns, value.st_mode, value.st_uid, value.st_nlink)
        data = os.fsencode(os.readlink(path)) if path.is_symlink() else path.read_bytes()
        require(identity(path.lstat()) == identity(info), 'baseline changed while reading')
        row.update(head_sha256=row['sha256'], sha256=digest(data), data=data, mode=stat.S_IMODE(info.st_mode), working_oid=hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest())
        identities.append(dict(path=row['path'], identity=list(identity(info))))
    require(before == git(repo, 'status', '--porcelain', '--untracked-files=no', '--', 'tmux/tools').decode() and git(repo, 'rev-parse', 'HEAD').decode().strip() == commit, 'baseline changed during snapshot')
    entries = [{key: value for key, value in row.items() if key != 'data'} for row in rows]
    return rows, dict(sha256=digest(json_bytes(entries)), entries=entries, dirty_inventory=before, identities=identities)


def inventory(root):
    entries = []
    for path in sorted(root.rglob('*')):
        relative = str(path.relative_to(root))
        if relative == 'package-manifest.json':
            continue
        info = path.lstat()
        item = dict(path=relative, mode=stat.S_IMODE(info.st_mode), uid=info.st_uid)
        require(info.st_uid == os.geteuid(), 'package owner mismatch')
        if stat.S_ISLNK(info.st_mode):
            target = os.readlink(path)
            require(not Path(target).is_absolute() and root in path.resolve().parents and path.resolve().exists(), 'external or dangling package link')
            item.update(kind='symlink', target=target, sha256=digest(os.fsencode(target)))
        elif stat.S_ISREG(info.st_mode):
            require(info.st_nlink == 1, 'package hardlink refused')
            item.update(kind='file', size=info.st_size, sha256=digest(path.read_bytes()))
        elif stat.S_ISDIR(info.st_mode):
            item.update(kind='directory')
        else:
            raise ValueError('special package file refused')
        if item['kind'] != 'symlink':
            require(not item['mode'] & 0o222, 'package is writable: ' + relative)
        entries.append(item)
    return entries


def validate_config(config, root):
    require(set(config) == {'version', 'transport', 'package', 'relay', 'send', 'store', 'inbox', 'socket'}, 'transport fields mismatch')
    require(config['version'] == 'relay-package-1' and config['package'] == str(root), 'transport package mismatch')
    require(config['relay'] == str(root / 'bin/relay') and config['send'] == str(root / 'bin/cc-msg'), 'transport entry mismatch')
    canonical(config['socket'])
    if config['transport'] == 'rust-v1':
        desk_path(config['store'])
        require(config['inbox'] is None, 'Rust inbox refused')
    else:
        require(config['transport'] == 'python-v1' and config['store'] is None, 'transport type refused')
        canonical(config['inbox'])


def verify_package(root, expected_hash=None):
    root = canonical(root)
    info = root.lstat()
    require(stat.S_ISDIR(info.st_mode) and info.st_uid == os.geteuid() and stat.S_IMODE(info.st_mode) == 0o500, 'package root mode or owner mismatch')
    manifest_path = root / 'package-manifest.json'
    require(stat.S_IMODE(regular(manifest_path).st_mode) == 0o400, 'manifest mode mismatch')
    raw = manifest_path.read_bytes()
    if expected_hash is not None:
        require(digest(raw) == expected_hash, 'package manifest hash mismatch')
    manifest = json.loads(raw)
    require(manifest['schema'] == 'relay-package-manifest' and manifest['version'] == 1 and manifest['package'] == str(root), 'package manifest identity mismatch')
    require(re.fullmatch('[0-9a-f]{40}', manifest['commit']) is not None, 'invalid source pin')
    snapshot = manifest.get('working_tree')
    expected_name = ('rust-' if manifest['transport'] == 'rust-v1' else 'python-') + manifest['commit']
    if snapshot is not None:
        require(manifest['transport'] == 'python-v1' and snapshot['entries'] == manifest['sources'] and snapshot['sha256'] == digest(json_bytes(manifest['sources'])), 'working tree snapshot pin mismatch')
        expected_name += '-' + snapshot['sha256']
    require(root.name == expected_name, 'package source pin mismatch')
    require(manifest['entries'] == inventory(root), 'package file inventory mismatch')
    config = json.loads((root / 'transport.json').read_bytes())
    validate_config(config, root)
    require(config['transport'] == manifest['transport'], 'transport manifest mismatch')
    require(json.loads((root / 'deployment.json').read_bytes()) == dict(config, uid=os.geteuid()), 'deployment configuration mismatch')
    sources = {row['path']: row for row in manifest['sources']}
    require(len(sources) == len(manifest['sources']), 'duplicate source entry')
    for name, row in sources.items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts, 'unsafe source inventory')
        path = root / 'src' / name
        data = os.fsencode(os.readlink(path)) if row['gitmode'] == '120000' else path.read_bytes()
        require(digest(data) == row['sha256'] and hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest() == row.get('working_oid', row['oid']), 'source blob mismatch: ' + name)
        if row['gitmode'] != '120000':
            require(not path.is_symlink() and stat.S_IMODE(path.stat().st_mode) == (row.get('mode', int(row['gitmode'][-3:], 8)) & ~0o222), 'source mode mismatch')
    require(digest((root / 'launch').read_bytes()) == manifest['dispatcher_sha256'], 'dispatcher mismatch')
    for surface, wrapper in SURFACES.items():
        require((root / 'bin' / surface).is_symlink() and os.readlink(root / 'bin' / surface) == '../launch', 'package entry link mismatch')
        require('tmux/tools/' + wrapper in sources, 'wrapper missing from pinned source')
    if config['transport'] == 'rust-v1':
        require(all(path in sources for path in RUST_PATHS if path != 'tmux/rust/src'), 'Rust helper or source missing')
        require(any(name.startswith('tmux/rust/src/') for name in sources), 'Rust crate source missing')
        require((root / 'launch').read_bytes() == (root / 'src/tmux/cutover/launch.py').read_bytes(), 'dispatcher source pin mismatch')
        require(regular(root / 'src/tmux/tools/angelstar-runtime').st_mode & 0o100, 'runtime not executable')
    return manifest, digest(raw)


def build_package(repo, commit, root, transport, dispatcher, store, inbox, socket, uid, toolchain=TOOLCHAIN, build_dir=None, cache_home=None):
    root = desk_path(root)
    require(uid == os.geteuid() and not os.path.lexists(root), 'package exists or uid mismatch')
    snapshot = None
    if transport == 'python-v1':
        sources, snapshot = working_tree_snapshot(repo, commit)
    else:
        sources = source_tree(repo, commit, RUST_PATHS)
    expected_name = ('rust-' if transport == 'rust-v1' else 'python-') + commit + ('-' + snapshot['sha256'] if snapshot else '')
    require(root.name == expected_name, 'final package path must contain source commit and snapshot pin')
    names = {row['path'] for row in sources}
    require(all('tmux/tools/' + wrapper in names for wrapper in SURFACES.values()), 'source wrappers missing')
    if transport == 'rust-v1':
        require(all(name in names for name in RUST_PATHS if name != 'tmux/rust/src'), 'required Rust source missing')
        dispatcher = next(row['data'] for row in sources if row['path'] == 'tmux/cutover/launch.py')
    config = dict(version='relay-package-1', transport=transport, package=str(root), relay=str(root / 'bin/relay'), send=str(root / 'bin/cc-msg'), store=str(store) if transport == 'rust-v1' else None, inbox=str(inbox) if transport == 'python-v1' else None, socket=str(socket))
    validate_config(config, root)
    root.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    root.mkdir(mode=0o700)
    (root / 'src').mkdir(mode=0o700)
    (root / 'bin').mkdir(mode=0o700)
    for row in sources:
        path = root / 'src' / row['path']
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        if row['gitmode'] == '120000':
            target = os.fsdecode(row['data'])
            require(not Path(target).is_absolute() and root in (path.parent / target).resolve().parents, 'unsafe source link')
            path.symlink_to(target)
        else:
            path.write_bytes(row['data'])
            path.chmod(row.get('mode', int(row['gitmode'][-3:], 8)))
    (root / 'launch').write_bytes(dispatcher)
    (root / 'launch').chmod(0o700)
    (root / 'transport.json').write_bytes(json_bytes(config))
    (root / 'deployment.json').write_bytes(json_bytes(dict(config, uid=uid)))
    provenance = {}
    if transport == 'rust-v1':
        toolchain = canonical(toolchain)
        build_dir = desk_path(build_dir)
        require(root not in build_dir.parents and build_dir not in root.parents, 'package and build directories must be separate')
        require(not os.path.lexists(build_dir), 'build directory already exists')
        build_dir.mkdir(mode=0o700, parents=True)
        cargo_home = build_dir / 'cargo-home'
        cargo_home.mkdir(mode=0o700)
        cache_home = Path(cache_home or os.environ.get('CARGO_HOME', Path.home() / '.cargo'))
        if (cache_home / 'registry').is_dir():
            shutil.copytree(cache_home / 'registry', cargo_home / 'registry')
        environment = os.environ.copy()
        environment.update(PATH=str(toolchain) + ':/usr/bin:/bin:/opt/homebrew/bin', RUSTC=str(toolchain / 'rustc'), CARGO_TARGET_DIR=str(build_dir), CARGO_HOME=str(cargo_home))
        for key in list(environment):
            if key.startswith(('CARGO_BUILD_', 'CARGO_TARGET_', 'RUSTFLAGS', 'CARGO_ENCODED_RUSTFLAGS', 'RUSTC_WRAPPER', 'RUSTC_WORKSPACE_WRAPPER')) and key != 'CARGO_TARGET_DIR':
                environment.pop(key)
        for name in ('cargo', 'rustc'):
            executable = toolchain / name
            provenance[name] = dict(path=str(executable), sha256=digest(executable.read_bytes()), version=subprocess.check_output([str(executable), '--version'], env=environment).decode().strip())
        arguments = [str(toolchain / 'cargo'), 'build', '--release', '--locked', '--offline', '--manifest-path', str(root / 'src/tmux/rust/Cargo.toml')]
        provenance['build'] = dict(arguments=arguments, cargo_home=str(cargo_home), target_directory=str(build_dir))
        subprocess.run(arguments, env=environment, cwd=root, check=True)
        binary = build_dir / 'release/angelstar-runtime'
        regular(binary)
        shutil.copyfile(binary, root / 'src/tmux/tools/angelstar-runtime')
        (root / 'src/tmux/tools/angelstar-runtime').chmod(0o700)
    for surface in SURFACES:
        (root / 'bin' / surface).symlink_to('../launch')
    if snapshot is not None:
        require(working_tree_snapshot(repo, commit)[1] == snapshot, 'baseline changed during package copy')
    for path in sorted(root.rglob('*'), reverse=True):
        if not path.is_symlink():
            path.chmod(stat.S_IMODE(path.stat().st_mode) & ~0o222)
    manifest = dict(schema='relay-package-manifest', version=1, package=str(root), transport=transport, commit=commit, dispatcher_sha256=digest(dispatcher), sources=[{key: value for key, value in row.items() if key != 'data'} for row in sources], working_tree=snapshot, toolchain=provenance, entries=inventory(root))
    (root / 'package-manifest.json').write_bytes(json_bytes(manifest))
    (root / 'package-manifest.json').chmod(0o400)
    root.chmod(0o500)
    return verify_package(root)[1]


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest='command', required=True)
    check = commands.add_parser('check')
    check.add_argument('package', type=Path)
    check.add_argument('--manifest-hash')
    build = commands.add_parser('build')
    build.add_argument('--commit', required=True)
    build.add_argument('--repo', type=Path, default=DESK / 'lab/tmux-to-rust')
    build.add_argument('--stable', type=Path, default=Path.home() / '.local/share/relay-stable')
    build.add_argument('--packages', type=Path, default=DESK / 'relay-packages')
    build.add_argument('--store', type=Path, default=DESK / 'relay-store-v1')
    build.add_argument('--inbox', type=Path, required=True)
    build.add_argument('--socket', required=True)
    build.add_argument('--uid', type=int, required=True)
    build.add_argument('--toolchain', type=Path, default=TOOLCHAIN)
    build.add_argument('--cache-home', type=Path)
    args = parser.parse_args()
    if args.command == 'check':
        print(verify_package(args.package, args.manifest_hash)[1])
        return
    require(args.uid == os.geteuid(), 'expected uid mismatch')
    pin(args.repo, args.commit)
    require(git(args.stable, 'rev-parse', 'HEAD').decode().strip() == BASELINE, 'baseline HEAD mismatch')
    dispatcher = git(args.repo, 'show', args.commit + ':tmux/cutover/launch.py')
    rust = desk_path(args.packages / ('rust-' + args.commit))
    snapshot = working_tree_snapshot(args.stable, BASELINE)[1]
    baseline = desk_path(args.packages / ('python-' + BASELINE + '-' + snapshot['sha256']))
    require(not os.path.lexists(rust) and not os.path.lexists(baseline), 'immutable package already exists')
    hashes = {}
    hashes[str(baseline)] = build_package(args.stable, BASELINE, baseline, 'python-v1', dispatcher, args.store, args.inbox, args.socket, args.uid)
    hashes[str(rust)] = build_package(args.repo, args.commit, rust, 'rust-v1', dispatcher, args.store, args.inbox, args.socket, args.uid, args.toolchain, DESK / 'tmp/relay' / ('s6x-build-' + args.commit), args.cache_home)
    print(json.dumps(dict(packages=hashes, stable_drift=git(args.stable, 'status', '--porcelain', '--untracked-files=no').decode()), sort_keys=True))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print('relay package refused: ' + str(error), file=sys.stderr)
        sys.exit(1)
