from pathlib import Path
import os
import random
import shlex
import shutil
import subprocess

source = (Path(__file__).resolve().parents[1] / 'tools/relay-delivery.sh').read_text()
function = source[source.index('relay_shell_join()'):source.index('relay_route_command()')]
arguments = ['a b', "single'quote", '$(printf substituted)', '`printf substituted`',
             '❯', 'line\nbreak', '', '#{pane_id}', 'back\\slash',
             'config CC (test) <-> rp / "quoted"', "display-message -p '__SENT__'"]
rng = random.Random(20261006)
arguments += [''.join(rng.choices('abc \'\\"$`;()<>/❯', k=40)) for _ in range(100)]
shells = list(dict.fromkeys(shell for shell in ['/bin/bash', shutil.which('bash'), '/opt/homebrew/bin/bash']
                           if shell and Path(shell).exists()))
socket = 'ccmsg-lab-private-quote-' + str(os.getpid())
def tmux(*args):
    return subprocess.run(['tmux', '-L', socket, '-f', '/dev/null', *args],
                          capture_output=True, text=True, check=True)
try:
    tmux('new-session', '-d', '-s', 'quote-lab', 'sleep 120')
    for shell in shells:
        result = subprocess.run([shell, '-c', function + 'relay_shell_join "$@"', 'lab', *arguments],
                                capture_output=True, text=True, check=True)
        assert shlex.split(result.stdout) == arguments, shell
        parsed = subprocess.run(['sh', '-c', 'printf "%s\\0" ' + result.stdout],
                                capture_output=True, check=True)
        assert parsed.stdout.split(b'\0')[:-1] == [value.encode() for value in arguments], shell
        for value in arguments:
            deliver = 'display-message -p -l ' + shlex.quote(value)
            nested = subprocess.check_output([shell, '-c', function + 'relay_shell_join "$@"', 'lab',
                                              'if-shell', '-F', '-t', 'quote-lab', '1', deliver,
                                              'display-message -p BLOCK'], text=True)
            receipt = tmux('if-shell', '-t', 'quote-lab', 'true', nested, 'display-message -p OUTERBLOCK')
            assert receipt.stdout == value + '\n', (shell, value, receipt.stdout)
finally:
    subprocess.run(['tmux', '-L', socket, 'kill-server'], capture_output=True)
print(f'PASS: {len(shells)} Bash versions, {len(arguments)} literal/fuzz arguments each, shell and nested tmux paths')
