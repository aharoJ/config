#!/usr/bin/python3
import argparse
import fcntl
import json
import os
from pathlib import Path
import stat
import sys
import time
import uuid

from package import BASELINE, DESK, SURFACES, canonical, desk_path, digest, git, json_bytes, regular, require, verify_package, working_tree_snapshot


def file_state(path):
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_uid == os.geteuid(), 'caller is not an owned regular file: ' + str(path))
    return dict(hash=digest(path.read_bytes()), mode=stat.S_IMODE(info.st_mode), uid=info.st_uid, device=info.st_dev, inode=info.st_ino, links=info.st_nlink)


def aliases(path):
    path = Path(path)
    require(path.is_absolute(), 'absolute caller path required')
    result = []
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current = current / part
        if current.is_symlink():
            info = current.lstat()
            require(info.st_uid == os.geteuid(), 'alias owner mismatch')
            result.append(dict(path=str(current), target=os.readlink(current), mode=stat.S_IMODE(info.st_mode), uid=info.st_uid))
    return result


def stable_state(stable, manifest):
    require(git(stable, 'rev-parse', 'HEAD').decode().strip() == BASELINE, 'stable HEAD mismatch')
    require(manifest.get('working_tree') is not None, 'baseline working tree snapshot required')
    current = working_tree_snapshot(stable, BASELINE)[1]
    expected = manifest['working_tree']
    require(current['sha256'] == expected['sha256'] and current['dirty_inventory'] == expected['dirty_inventory'], 'stable checkout drift from pinned snapshot')


def link_target(path, mode=None):
    info = path.lstat()
    require(stat.S_ISLNK(info.st_mode) and info.st_uid == os.geteuid() and (mode is None or stat.S_IMODE(info.st_mode) == mode), 'unexpected public link mode/type/owner: ' + str(path))
    return os.readlink(path)


def parent_state(path):
    path = canonical(path)
    info = path.lstat()
    require(stat.S_ISDIR(info.st_mode) and info.st_uid == os.geteuid() and not stat.S_IMODE(info.st_mode) & 0o022, 'unsafe parent: ' + str(path))
    return dict(path=str(path), device=info.st_dev, inode=info.st_ino, mode=stat.S_IMODE(info.st_mode), uid=info.st_uid)


def sync_directory(path):
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def write_exclusive(path, data, mode):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
    with os.fdopen(descriptor, 'wb') as stream:
        stream.write(data)
        stream.flush()
        os.fchmod(stream.fileno(), mode)
        os.fsync(stream.fileno())


def prepare(migration, baseline, candidate, transaction, home, stable):
    transaction = desk_path(transaction)
    home, stable = canonical(home), canonical(stable)
    require(not os.path.lexists(transaction), 'transaction already exists')
    baseline_manifest, baseline_hash = verify_package(baseline)
    candidate_manifest, candidate_hash = verify_package(candidate)
    require(baseline_manifest['transport'] == 'python-v1' and baseline_manifest['commit'] == BASELINE and candidate_manifest['transport'] == 'rust-v1', 'wrong package roles or baseline pin')
    require(baseline_manifest['dispatcher_sha256'] == candidate_manifest['dispatcher_sha256'], 'package dispatcher versions differ')
    stable_state(stable, baseline_manifest)
    baseline_config = json.loads((baseline / 'transport.json').read_bytes())
    candidate_config = json.loads((candidate / 'transport.json').read_bytes())
    require(baseline_config['socket'] == candidate_config['socket'], 'package sockets differ')
    pointer = home / '.local/share/relay-current'
    require(not os.path.lexists(pointer), 'unexpected existing installation pointer')
    parents = {str(path): parent_state(path) for path in (pointer.parent, home / '.local/bin')}
    links = []
    for name, wrapper in SURFACES.items():
        public = home / '.local/bin' / name
        expected = str(stable / 'tmux/tools' / wrapper)
        require(link_target(public) == expected, 'unexpected baseline link: ' + str(public))
        require(digest(public.resolve(strict=True).read_bytes()) == next(row['sha256'] for row in baseline_manifest['sources'] if row['path'] == 'tmux/tools/' + wrapper), 'live wrapper differs from baseline')
        links.append(dict(path=str(public), before=expected, after=str(pointer / 'bin' / name), mode=stat.S_IMODE(public.lstat().st_mode)))
    migration = desk_path(migration)
    regular(migration)
    raw = migration.read_bytes()
    manifest = json.loads(raw)
    require(manifest.get('schema') == 'relay-caller-migration' and manifest.get('version') == 1 and isinstance(manifest.get('entries'), list), 'migration schema refused')
    callers = {}
    for entry in manifest['entries']:
        require(set(entry) == {'path', 'beforehash', 'stagedpath', 'afterhash', 'reason'} and isinstance(entry['reason'], str) and entry['reason'], 'migration entry fields refused')
        path = Path(entry['path'])
        require(path.is_absolute() and str(path) == os.path.normpath(str(path)), 'caller path must be absolute and normalized')
        if entry['beforehash'] is None:
            require(not os.path.lexists(path), 'new caller unexpectedly exists: ' + str(path))
            resolved = path.parent.resolve(strict=True) / path.name
            state = None
        else:
            resolved = path.resolve(strict=True)
            state = file_state(resolved)
            require(state['hash'] == entry['beforehash'], 'caller beforehash mismatch: ' + str(path))
        require(home in resolved.parents, 'caller outside declared home')
        require(resolved != pointer and resolved not in [Path(row['path']) for row in links], 'caller collides with installation surface')
        staged = desk_path(entry['stagedpath'])
        staged_info = regular(staged)
        require(digest(staged.read_bytes()) == entry['afterhash'], 'staged afterhash mismatch')
        key = str(resolved)
        after_mode = state['mode'] if state else stat.S_IMODE(staged_info.st_mode)
        value = dict(destination=key, before=state, afterhash=entry['afterhash'], after_mode=after_mode, stagedpath=str(staged), aliases=[dict(path=str(path), chain=aliases(path))])
        if key in callers:
            previous = callers[key]
            require(previous['before'] == state and previous['afterhash'] == entry['afterhash'] and previous['after_mode'] == after_mode, 'same-destination migration collision')
            previous['aliases'] += value['aliases']
        else:
            callers[key] = value
        parents[str(resolved.parent)] = parent_state(resolved.parent)
    groups = {}
    for entry in callers.values():
        state = entry['before']
        if state is None:
            entry['hardlinks'] = [entry['destination']]
        else:
            groups.setdefault((state['device'], state['inode']), []).append(entry)
    for group in groups.values():
        require(len(group) == group[0]['before']['links'], 'undiscovered hardlink aliases; expand migration manifest')
        require(len({entry['afterhash'] for entry in group}) == 1, 'hardlinked callers have conflicting migrations')
        names = sorted(entry['destination'] for entry in group)
        for entry in group:
            entry['hardlinks'] = names
    transaction.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    transaction.mkdir(mode=0o700)
    payloads = []
    for number, entry in enumerate(sorted(callers.values(), key=lambda row: row['destination'])):
        entry['backup'] = f'{number:04d}.before' if entry['before'] else None
        entry['prepared'] = f'{number:04d}.after'
        contents = [(entry['prepared'], Path(entry['stagedpath']).read_bytes())]
        if entry['backup'] is not None:
            contents.append((entry['backup'], Path(entry['destination']).read_bytes()))
        for name, content in contents:
            write_exclusive(transaction / name, content, 0o400)
            payloads.append(dict(path=name, sha256=digest(content), mode=0o400))
    write_exclusive(transaction / 'migration.json', raw, 0o400)
    payloads.append(dict(path='migration.json', sha256=digest(raw), mode=0o400))
    write_exclusive(transaction / 'journal.jsonl', b'', 0o600)
    write_exclusive(transaction / 'lock', b'', 0o600)
    plan = dict(schema='relay-cutover-prepared', version=1, uid=os.geteuid(), transaction=str(transaction), home=str(home), stable=str(stable), baseline=str(baseline), candidate=str(candidate), baseline_manifest=baseline_hash, candidate_manifest=candidate_hash, pointer=str(pointer), socket=candidate_config['socket'], store=candidate_config['store'], inbox=baseline_config['inbox'], links=links, callers=sorted(callers.values(), key=lambda row: row['destination']), parents=list(parents.values()), payloads=payloads)
    write_exclusive(transaction / 'prepared.json', json_bytes(plan), 0o400)
    sync_directory(transaction)
    prepared_hash = digest((transaction / 'prepared.json').read_bytes())
    check(transaction, prepared_hash)
    return prepared_hash


def load_plan(transaction, expected_hash):
    transaction = desk_path(transaction)
    require(stat.S_IMODE(transaction.lstat().st_mode) == 0o700, 'transaction mode mismatch')
    path = transaction / 'prepared.json'
    require(stat.S_IMODE(regular(path).st_mode) == 0o400, 'prepared manifest mode mismatch')
    raw = path.read_bytes()
    require(digest(raw) == expected_hash, 'prepared manifest hash mismatch')
    plan = json.loads(raw)
    require(plan['schema'] == 'relay-cutover-prepared' and plan['version'] == 1 and plan['uid'] == os.geteuid() and plan['transaction'] == str(transaction), 'prepared identity mismatch')
    return plan


def check(transaction, expected_hash, phase='before'):
    plan = load_plan(transaction, expected_hash)
    baseline_manifest, _ = verify_package(Path(plan['baseline']), plan['baseline_manifest'])
    verify_package(Path(plan['candidate']), plan['candidate_manifest'])
    stable_state(Path(plan['stable']), baseline_manifest)
    expected_files = {'prepared.json', 'journal.jsonl', 'lock', *[item['path'] for item in plan['payloads']]}
    require({p.name for p in transaction.iterdir()} == expected_files, 'unexpected transaction files; inspect journal')
    for name in ('lock', 'journal.jsonl'):
        require(stat.S_IMODE(regular(transaction / name).st_mode) == 0o600, 'transaction control mode mismatch')
    for item in plan['payloads']:
        path = transaction / item['path']
        require(stat.S_IMODE(regular(path).st_mode) == item['mode'] and digest(path.read_bytes()) == item['sha256'], 'prepared payload mismatch')
    for parent in plan['parents']:
        require(parent_state(Path(parent['path'])) == parent, 'destination parent changed')
    pointer = Path(plan['pointer'])
    if phase == 'after':
        require(link_target(pointer, 0o777) == plan['candidate'], 'candidate pointer mismatch')
    else:
        require(not os.path.lexists(pointer) or link_target(pointer, 0o777) == plan['baseline'], 'unexpected current pointer')
    for row in plan['links']:
        target = link_target(Path(row['path']), row['mode'])
        require(target in (row['before'], row['after']) if phase != 'after' else target == row['after'], 'public entry changed')
        if target == row['after']:
            require(os.path.lexists(pointer), 'enrolled public without baseline pointer')
    current_groups = {}
    for entry in plan['callers']:
        path = Path(entry['destination'])
        require(path.resolve() == path, 'caller destination alias changed')
        if not os.path.lexists(path):
            require(entry['before'] is None and phase != 'after', 'caller disappeared')
            state = None
        else:
            state = file_state(path)
            require(state['mode'] == entry['after_mode'], 'caller mode changed')
            if entry['before'] is None:
                require(phase in ('resume', 'after') and state['hash'] == entry['afterhash'], 'new caller unexpectedly exists')
            else:
                allowed = (entry['before']['hash'], entry['afterhash']) if phase == 'resume' else ((entry['afterhash'],) if phase == 'after' else (entry['before']['hash'],))
                require(state['hash'] in allowed, 'caller content changed: ' + str(path))
                if phase == 'before':
                    require(state == entry['before'], 'caller metadata changed')
            require(state['links'] <= len(entry['hardlinks']), 'unexpected hardlink alias')
        staged = Path(entry['stagedpath'])
        regular(staged)
        require(digest(staged.read_bytes()) == entry['afterhash'], 'staged source changed')
        for alias in entry['aliases']:
            require(Path(alias['path']).resolve() == path and aliases(alias['path']) == alias['chain'], 'caller alias changed')
        if phase == 'after':
            key = tuple(entry['hardlinks'])
            current_groups.setdefault(key, set()).add((state['device'], state['inode']))
    require(all(len(group) == 1 for group in current_groups.values()), 'caller hardlinks not preserved')
    return plan


def journal(transaction, operation, **fields):
    path = transaction / 'journal.jsonl'
    regular(path)
    descriptor = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'ab') as stream:
        stream.write(json_bytes(dict(time=time.time(), operation=operation, **fields)).replace(b'\n', b'') + b'\n')
        stream.flush()
        os.fsync(stream.fileno())


def atomic_link(path, target, expected):
    if expected is None:
        require(not os.path.lexists(path), 'pointer appeared before enrollment')
    else:
        require(link_target(path) == expected, 'link changed before replacement')
    mode = 0o777 if expected is None else stat.S_IMODE(path.lstat().st_mode)
    temporary = path.with_name('.' + path.name + '.relay-' + uuid.uuid4().hex)
    temporary.symlink_to(target)
    if hasattr(os, 'lchmod'):
        os.lchmod(temporary, mode)
    if expected is None:
        require(not os.path.lexists(path), 'pointer appeared during enrollment')
        os.link(temporary, path, follow_symlinks=False)
        temporary.unlink()
    else:
        require(link_target(path, mode) == expected, 'link changed during replacement')
        os.replace(temporary, path)
    sync_directory(path.parent)


def verify_drain(plan, report, report_hash):
    report = desk_path(report)
    regular(report)
    raw = report.read_bytes()
    require(digest(raw) == report_hash, 'drain report hash mismatch')
    evidence = json.loads(raw)
    require(evidence['schema'] == 'relay-drain-1' and evidence['clear'] is True and evidence['socket'] == plan['socket'] and plan['inbox'] in evidence['roots'] and evidence['rust']['path'] == plan['store'], 'drain scope mismatch or blocked')
    from drain import collect
    fresh = collect(Path(plan['socket']), [Path(root) for root in evidence['roots']], Path(plan['store']))
    require(fresh['clear'] is True and all(fresh[key] == evidence[key] for key in ('socket', 'server_pid', 'server_generation', 'socket_device', 'socket_inode')), 'drain or server identity changed')
    return fresh


def activate(transaction, expected_hash, report, report_hash, resume=False):
    plan = check(transaction, expected_hash, 'resume' if resume else 'before')
    verify_drain(plan, report, report_hash)
    with (transaction / 'lock').open('r+b') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        plan = check(transaction, expected_hash, 'resume' if resume else 'before')
        journal(transaction, 'activation-start', resume=resume)
        try:
            pointer = Path(plan['pointer'])
            if not os.path.lexists(pointer):
                atomic_link(pointer, plan['baseline'], None)
                journal(transaction, 'baseline-pointer-enrolled')
            for row in plan['links']:
                path = Path(row['path'])
                if link_target(path) == row['before']:
                    atomic_link(path, row['after'], row['before'])
                    journal(transaction, 'public-enrolled', path=str(path))
            handled = set()
            for entry in plan['callers']:
                group = tuple(entry['hardlinks'])
                if group in handled:
                    continue
                handled.add(group)
                first = Path(group[0])
                for name in group:
                    path = Path(name)
                    current = file_state(path) if os.path.lexists(path) else None
                    if entry['before'] is None:
                        if current is not None:
                            require(resume and current['hash'] == entry['afterhash'] and current['mode'] == entry['after_mode'] and current['links'] == 1, 'new caller changed during migration')
                            continue
                    else:
                        require(current is not None and current['hash'] in (entry['before']['hash'], entry['afterhash']) and current['mode'] == entry['after_mode'], 'caller changed during migration')
                    temporary = path.with_name('.' + path.name + '.relay-' + uuid.uuid4().hex)
                    journal(transaction, 'caller-replace-start', path=name, temporary=str(temporary), backup=entry['backup'])
                    if path == first:
                        write_exclusive(temporary, (transaction / entry['prepared']).read_bytes(), entry['after_mode'])
                    else:
                        os.link(first, temporary)
                    if entry['before'] is None:
                        require(not os.path.lexists(path), 'new caller appeared before creation')
                        os.link(temporary, path)
                        temporary.unlink()
                    else:
                        require(file_state(path) == current, 'caller changed before atomic replacement')
                        os.replace(temporary, path)
                    sync_directory(path.parent)
                    journal(transaction, 'caller-replaced', path=name)
            verified = check(transaction, expected_hash, 'resume')
            for entry in verified['callers']:
                require(file_state(Path(entry['destination']))['hash'] == entry['afterhash'], 'migration incomplete')
            for group in handled:
                require(len({(Path(name).stat().st_dev, Path(name).stat().st_ino) for name in group}) == 1, 'hardlink migration incomplete')
            verify_drain(plan, report, report_hash)
            atomic_link(pointer, plan['candidate'], plan['baseline'])
            journal(transaction, 'candidate-activated')
            check(transaction, expected_hash, 'after')
        except Exception as error:
            journal(transaction, 'activation-stopped', error=str(error), recovery='Keep Python pointer until migration complete. Inspect backups/journal; rerun --activate --resume with a fresh drain, or --rollback if candidate pointer is active.')
            raise
    return plan


def rollback(transaction, expected_hash):
    plan = load_plan(transaction, expected_hash)
    pointer = Path(plan['pointer'])
    require(pointer.is_symlink(), 'rollback requires an existing symlink pointer')
    require(link_target(pointer, 0o777) == plan['candidate'], 'rollback requires exact current candidate target')
    verify_package(Path(plan['baseline']), plan['baseline_manifest'])
    verify_package(Path(plan['candidate']), plan['candidate_manifest'])
    for row in plan['links']:
        require(link_target(Path(row['path']), row['mode']) == row['after'], 'rollback public link mismatch')
    with (transaction / 'lock').open('r+b') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        require(link_target(pointer) == plan['candidate'], 'rollback candidate changed')
        atomic_link(pointer, plan['baseline'], plan['candidate'])
        journal(transaction, 'rolled-back-to-python', callers='dual-compatible migrated callers retained', rust_store_retained=plan['store'])
    return plan


def main():
    parser = argparse.ArgumentParser()
    operations = parser.add_mutually_exclusive_group(required=True)
    for name in ('prepare', 'check', 'dry-run', 'activate', 'rollback'):
        operations.add_argument('--' + name, action='store_true')
    parser.add_argument('--transaction', type=Path, required=True)
    parser.add_argument('--prepared-hash')
    parser.add_argument('--migration', type=Path)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--candidate', type=Path)
    parser.add_argument('--home', type=Path, default=Path.home())
    parser.add_argument('--stable', type=Path, default=Path.home() / '.local/share/relay-stable')
    parser.add_argument('--drain', type=Path)
    parser.add_argument('--drain-hash')
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        require(all((args.migration, args.baseline, args.candidate)), 'prepare requires migration and both packages')
        print(prepare(args.migration, args.baseline, args.candidate, args.transaction, args.home, args.stable))
        return
    require(args.prepared_hash is not None, 'external prepared manifest hash required')
    if args.rollback:
        rollback(args.transaction, args.prepared_hash)
    else:
        require(args.drain is not None and args.drain_hash is not None, 'fresh drain report and hash required')
        if args.activate:
            activate(args.transaction, args.prepared_hash, args.drain, args.drain_hash, args.resume)
        else:
            plan = check(args.transaction, args.prepared_hash, 'resume' if args.resume else 'before')
            verify_drain(plan, args.drain, args.drain_hash)
    print(json.dumps(dict(operation='rollback' if args.rollback else ('activate' if args.activate else 'checked-no-writes'), transaction=str(args.transaction))))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        print('relay install refused: ' + str(error), file=sys.stderr)
        sys.exit(1)
