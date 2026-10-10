import json
from pathlib import Path
import runpy
import sys

fixture = runpy.run_path(str(Path(__file__).with_name('relay-delivery-regression.py')))
matrix = fixture['Matrix'](sys.argv[1], validated_sources=True)
try:
    for name, options in [('default-shared', []), ('raw-unflagged', ['--model','fixture']), ('wrapper-remote', ['--no-daemon','--remote','unix:///remote']), ('flag-app-server', ['--config','model=fixture','--no-daemon','app-server','daemon']), ('future-subcommand', ['--no-daemon','future-subcommand'])]:
        for transport in ('direct','enqueue','queued'):
            matrix.sender_case(name+'-'+transport,'codex',code=1,actor_options=options,relay='cc-msg-queue' if transport=='enqueue' else 'cc-msg.sh',seeded_queue=transport=='queued')
    matrix.sender_case('local-native','codex')
    matrix.sender_case('delimited-future-prompt','codex',actor_options=['--no-daemon','--','future-subcommand'])
    matrix.sender_case('local-node-native-child','codex',node=True)
    matrix.sender_case('node-wrapper-remote','codex',node=True,actor_options=['--no-daemon','--remote','unix:///remote'],code=1)
    assert all(row['passed'] for row in matrix.results), matrix.results
    print('PASS 15 nonlocal direct/enqueue/queued refusals, native/Node positive sends and Node remote refusal')
finally:
    matrix.close()
