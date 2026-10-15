"""K63 narrow, RAM-only native keeper oracles; unsupported evidence refuses."""
import json
import errno
import re
import sqlite3
import os
import subprocess
from pathlib import Path

UUID = r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'


class SnapshotRefusal(ValueError):
    def __init__(self, reason, fixture):
        super().__init__(reason)
        self.fixture = fixture


def draft_snapshot(screen, meta, client, expected, probe, extra_reason=None, report=None):
    """Reuse the production Rust classifier; no Python terminal/input parser."""
    x, y, width, height = map(int, meta[:4])
    request = dict(capture=screen + '\n', glyph='❯' if client == 'claude' else '›',
                   x=x, y=y, width=width, expected=expected.decode('ascii'))
    env = {k: v for k, v in os.environ.items() if k != 'KS01_RUN_CAP' and not k.startswith('ANGELSTAR_')}
    result = subprocess.run([str(probe), '--exact', 'composer::tests::native_snapshot_probe',
                             '--ignored', '--nocapture'], input=json.dumps(request).encode(),
                            capture_output=True, env=env)
    fixture = dict(cursor_x=x, cursor_y=y, pane_width=width, pane_height=height,
                   native_capture_not_retained=True)
    if result.returncode:
        raise SnapshotRefusal('Rust snapshot probe exit=' + str(result.returncode), fixture)
    lines = [line[len(b'K65_SNAPSHOT '):] for line in result.stdout.splitlines()
             if line.startswith(b'K65_SNAPSHOT ')]
    if len(lines) != 1:
        raise SnapshotRefusal('Rust snapshot probe result count=' + str(len(lines)), fixture)
    observed = json.loads(lines[0])
    reason = extra_reason
    if meta[4:6] != ('0', '0'):
        reason = 'snapshot: pane dead or in copy mode'
    elif len(screen.split('\n')) != height:
        reason = 'snapshot: capture height differs from pane height'
    if report is not None:
        report(dict(observed, accepted=False, reason=reason) if reason else observed)
    if reason or not observed['accepted']:
        raise SnapshotRefusal(reason or observed['reason'], observed['fixture'])
    # screen(Staged) proved these exact bytes, or screen(Empty) proved b''.
    return (meta, expected)


def pending_no_input(exit_code, histories):
    forbidden = {'input-intent', 'pasted', 'submit-intent', 'submitted', 'input-unknown'}
    return (exit_code == 6 and len(histories) == 1 and bool(histories[0])
            and histories[0][-1] == 'pending-no-input'
            and not forbidden.intersection(histories[0]))


def exact_turn(turns, expected):
    return len(turns) == 1 and turns[0] == expected


def claude_turns(data, session):
    if data and not data.endswith(b'\n'):
        raise ValueError('partial native log')
    turns = []
    for line in data.splitlines():
        item = json.loads(line)
        if item.get('type') != 'user':
            continue
        if item.get('sessionId') != session or item.get('isSidechain') is not False:
            raise ValueError('foreign or sidechain user turn')
        message = item['message']
        if message.get('role') != 'user' or not item.get('uuid'):
            raise ValueError('unknown user turn')
        content = message['content']
        if isinstance(content, str):
            turns.append(content.encode())
        elif (isinstance(content, list) and len(content) == 1
              and content[0].get('type') == 'text' and isinstance(content[0].get('text'), str)):
            turns.append(content[0]['text'].encode())
        else:
            raise ValueError('non-text user turn')
    return turns


def codex_turns(items):
    turns = []
    for raw in items:
        item = json.loads(raw)
        content = item.get('content')
        if (item.get('type') != 'userMessage' or not isinstance(content, list)
                or len(content) != 1 or content[0].get('type') != 'text'
                or not isinstance(content[0].get('text'), str)):
            raise ValueError('unknown native user turn')
        turns.append(content[0]['text'].encode())
    return turns


def native_turns(client, session, cwd, launched_ms, codex_home=None):
    """Exact own session only. No directory enumeration, previews, or history scan."""
    if not re.fullmatch(UUID, session):
        raise ValueError('invalid native session')
    home = Path.home()
    if client == 'claude':
        project = re.sub(r'[^A-Za-z0-9]', '-', str(cwd))
        path = home / '.claude/projects' / project / (session + '.jsonl')
        with path.open('rb') as stream:
            data = stream.read(4 * 1024 * 1024 + 1)
        if len(data) > 4 * 1024 * 1024:
            raise ValueError('native log bound exceeded')
        return claude_turns(data, session)
    def connect(name):
        path = (Path(codex_home) if codex_home is not None else home / '.codex') / name
        if not path.exists():
            raise FileNotFoundError(errno.ENOENT, os.strerror(errno.ENOENT), str(path))
        return sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=.5)
    with connect('state_5.sqlite') as state:
        row = state.execute('SELECT cwd,cli_version,created_at_ms,history_mode FROM threads WHERE id=?', (session,)).fetchone()
    if not row:
        # Fresh interactive sessions need not persist until their first turn.
        # Absence is an empty pre-send history, and a pending post-send event.
        return []
    if (row[0] != str(cwd) or row[1] != '0.162.1'
            or row[2] is None or row[2] < launched_ms or row[3] != 'paginated'):
        raise ValueError('native session binding unproved')
    with connect('thread_history_1.sqlite') as history:
        rows = history.execute("SELECT item_json FROM thread_items WHERE thread_id=? AND item_type='userMessage' ORDER BY rollout_ordinal LIMIT 3", (session,)).fetchall()
    return codex_turns([row[0] for row in rows])
