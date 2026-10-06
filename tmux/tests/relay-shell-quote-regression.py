from pathlib import Path
import shlex
import subprocess

source = (Path(__file__).resolve().parents[1] / 'tools/relay-delivery.sh').read_text()
function = source[source.index('relay_shell_join()'):source.index('relay_route_command()')]
arguments = ['a b', "single'quote", '$(printf substituted)', '`printf substituted`',
             '❯', 'line\nbreak', '', '#{pane_id}', 'back\\slash']
result = subprocess.run(['bash', '-c', function + 'relay_shell_join "$@"', 'lab', *arguments],
                        capture_output=True, text=True, check=True)
assert shlex.split(result.stdout) == arguments
parsed = subprocess.run(['sh', '-c', 'printf "%s\\0" ' + result.stdout],
                        capture_output=True, check=True)
assert parsed.stdout.split(b'\0')[:-1] == [value.encode() for value in arguments]
print('PASS: portable shell quoting preserves literal arguments without substitutions')
