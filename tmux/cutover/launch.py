#!/usr/bin/python3
import json
import os
from pathlib import Path
import sys

SURFACES = {'relay': 'relay', 'cc-msg': 'cc-msg.sh', 'codex-send': 'codex-send', 'codex-send-to': 'codex-send-to'}


def main():
    root = Path(__file__).resolve().parent
    config = json.loads((root / 'transport.json').read_text())
    deployment = json.loads((root / 'deployment.json').read_text())
    if deployment != dict(config, uid=os.geteuid()):
        raise ValueError('deployment identity or configuration mismatch')
    surface = Path(sys.argv[0]).name
    if surface not in SURFACES or config['version'] != 'relay-package-1':
        raise ValueError('unknown installed surface or version')
    if config['package'] != str(root) or config['relay'] != str(root / 'bin/relay') or config['send'] != str(root / 'bin/cc-msg'):
        raise ValueError('package location mismatch')
    socket = config['socket']
    if not isinstance(socket, str) or not Path(socket).is_absolute() or str(Path(socket).resolve()) != socket:
        raise ValueError('noncanonical socket')
    environment = os.environ.copy()
    environment['PYTHONDONTWRITEBYTECODE'] = '1'
    pins = {'ANGELSTAR_RELAY_SOCKET': socket}
    if config['transport'] == 'rust-v1' and config['inbox'] is None and isinstance(config['store'], str):
        pins['ANGELSTAR_RELAY_STORE'] = config['store']
    elif config['transport'] == 'python-v1' and config['store'] is None and isinstance(config['inbox'], str):
        pins['CC_MSG_INBOX_ROOT'] = config['inbox']
        if environment.get('ANGELSTAR_RELAY_STORE'):
            raise ValueError('unexpected Rust store for Python transport')
        pins['TMUX_BIN'] = '/opt/homebrew/bin/tmux'
        if any(key.startswith('TMUX_LAB_') for key in environment):
            raise ValueError('test transport environment refused')
        tmux = environment.get('TMUX', '')
        if tmux and tmux.split(',')[0] != socket:
            raise ValueError('TMUX socket mismatch')
        environment['TMUX'] = tmux or socket + ',0,0'
    else:
        raise ValueError('invalid transport configuration')
    for key, value in pins.items():
        if key in environment and environment[key] != value:
            raise ValueError('installed environment mismatch: ' + key)
        environment[key] = value
    tool = root / 'src/tmux/tools' / SURFACES[surface]
    if tool.is_symlink() or not tool.is_file():
        raise ValueError('source wrapper refused')
    os.execve('/usr/bin/python3', ['/usr/bin/python3', '-B', str(tool), *sys.argv[1:]], environment)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('relay: installed dispatcher refused: ' + str(error), file=sys.stderr)
        sys.exit(1)
