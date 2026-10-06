#!/usr/bin/env python3
import contextlib
import io
import json
import os
import pathlib
import runpy
import sys
import tempfile
from unittest.mock import patch

script = pathlib.Path(__file__).resolve().parents[1] / 'tools/relay-archive'
with tempfile.TemporaryDirectory() as directory:
    home = pathlib.Path(directory)
    payload = home / 'payload'
    message = "summary with unmatched ' quote " + '界' * 300
    for number, app in enumerate(('claude', 'codex', 'agy', 'gemini', 'relay')):
        source = dict(app=app, session='config', window='codex')
        record = home / 'record'
        record.write_text(json.dumps(dict(source=source, message=message, id=f'{number:032x}', created=1791320000 + number)))
        output = io.StringIO()
        with patch.dict(os.environ, RELAY_MESSAGE_RECORD=str(record), RELAY_VISIBLE_LABEL='codex (config:codex) [gpt-6.1-sol low]'), patch.object(pathlib.Path, 'home', return_value=home), patch.object(sys, 'argv', [str(script), str(payload), '160']), contextlib.redirect_stdout(output):
            runpy.run_path(str(script), run_name='__main__')
        line = output.getvalue().strip()
        label = 'codex (config:codex) [gpt-6.1-sol low]: '
        assert line.startswith(label + 'summary with unmatched'), line
        assert line.count(label) == 1 and ' -- full: ~/desk/tmp/relay/' in line, line
        archived = home / line.split(' -- full: ~/')[1]
        assert archived.read_text() == message
        assert archived.stat().st_mode & 0o077 == 0
print('PASS: five providers/neutral sender retain uniform archive labels, summaries and exact private payloads')
