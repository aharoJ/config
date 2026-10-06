#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('clear', str(ROOT / 'tools/relay-clear-draft'))
spec = importlib.util.spec_from_loader(loader.name, loader)
clear = importlib.util.module_from_spec(spec)
loader.exec_module(clear)
FIXTURES = ROOT / 'tests/fixtures'


def fixture(kind):
    y = 9 if kind == 'claude' else 10
    return dict(capture=(FIXTURES / ('clear-' + kind + '-short.ansi')).read_text(), x=4, y=y, width=178, state='snapshot', fields=[])


class ClearGuardTests(unittest.TestCase):
    def setUp(self):
        route = patch.object(clear.queue, 'routing_source', return_value=dict(session='lab', window='codex', pane='%1'))
        route.start()
        self.addCleanup(route.stop)

    def test_real_typed_single_lines_pass(self):
        for kind in ('claude', 'codex'):
            self.assertIn('y=', clear.guard(fixture(kind), kind, 'y='))

    def test_expected_text_is_mandatory_and_short(self):
        for value in ('', 'x' * 17, 'first\nsecond', ' y=', 'y= ', '\x03', 'é', '[Pasted text #1]', '[Image #1]', '[a]'):
            with self.assertRaises(clear.Refused):
                clear.valid_expected(value)

    def test_operator_text_mismatch_and_cursor_home_refuse(self):
        for kind in ('claude', 'codex'):
            snap = fixture(kind)
            with self.assertRaises(clear.Refused):
                clear.guard(snap, kind, 'x=')
            snap['x'] = 2
            with self.assertRaises(clear.Refused):
                clear.guard(snap, kind, 'y=')

    def test_multiline_draft_refuses(self):
        for kind in ('claude', 'codex'):
            snap = fixture(kind)
            rows = snap['capture'].splitlines()
            rows.insert(snap['y'] + 1, 'operator second line')
            snap['capture'] = '\n'.join(rows) + '\n'
            with self.assertRaises(clear.Refused):
                clear.guard(snap, kind, 'y=')

    def test_dim_suggestion_and_concealed_input_refuse(self):
        for kind in ('claude', 'codex'):
            for sgr in ('2', '8', '7'):
                snap = fixture(kind)
                snap['capture'] = snap['capture'].replace('y=', '\x1b[' + sgr + 'my=\x1b[0m')
                with self.assertRaises(clear.Refused):
                    clear.guard(snap, kind, 'y=')

    def test_busy_clients_refuse_even_exact_draft(self):
        for kind in ('claude', 'codex'):
            snap = fixture(kind)
            rows = snap['capture'].splitlines()
            rows[snap['y'] - 2] = '✽ Thinking… (5s · ↓ 10 tokens)' if kind == 'claude' else '• Working (5s • esc to interrupt)'
            snap['capture'] = '\n'.join(rows) + '\n'
            with self.assertRaises(clear.Refused):
                clear.guard(snap, kind, 'y=')

    def test_claude_streaming_without_completion_refuses(self):
        snap = fixture('claude')
        snap['capture'] = snap['capture'].replace('Claude', 'Unproven', 1)
        with self.assertRaises(clear.Refused):
            clear.guard(snap, 'claude', 'y=')

    def test_untrusted_escape_or_trailing_text_refuses(self):
        for suffix in (' ', '\x1b]0;spoof\x07', '\x1b[2J'):
            snap = fixture('codex')
            snap['capture'] = snap['capture'].replace('y=', 'y=' + suffix)
            with self.assertRaises(clear.Refused):
                clear.guard(snap, 'codex', 'y=')

    def test_attachments_outside_text_row_refuse(self):
        for kind in ('claude', 'codex'):
            snap = fixture(kind)
            rows = snap['capture'].splitlines()
            rows[snap['y'] - 2] = '[Image #1]'
            snap['capture'] = '\n'.join(rows) + '\n'
            with self.assertRaises(clear.Refused):
                clear.guard(snap, kind, 'y=')

    def test_keystroke_proof_has_bounded_runtime(self):
        import os
        import sys
        import time
        import uuid
        lab = Path.home() / 'desk/lab/clear-draft/proof-tests' / uuid.uuid4().hex
        lab.mkdir(parents=True)
        socket = lab / 'socket'
        socket.touch()
        stub = lab / 'tmux'
        stub.write_text('#!' + sys.executable + '\nimport time\ntime.sleep(10)\n')
        stub.chmod(0o755)
        plan = lab / 'proof.plan'
        plan.write_text(json.dumps(dict(expires=time.time() + 30, environment=dict(CC_MSG_SESSION='lab', CC_MSG_WINDOW='claude', TMUX=str(socket), TMUX_BIN=str(stub)), identity={})))
        start = time.monotonic()
        result = subprocess.run([sys.executable, str(ROOT / 'tools/relay-clear-draft'), '--prove', str(plan)], capture_output=True, timeout=4)
        self.assertEqual(result.returncode, 1)
        self.assertLess(time.monotonic() - start, 3)

    def test_extended_colour_parameters_are_not_dim(self):
        cells = clear.styled_cells('\x1b[38;2;2;8;22my=\x1b[0m')
        self.assertEqual([(dim, hidden) for _, dim, hidden, _ in cells], [(False, False), (False, False)])

    def test_changed_identity_or_capture_refuses_at_keystroke_proof(self):
        target = dict(foreground=['123', '/claude'])
        plan = dict(record='/test/record', environment={}, identity=target, kind='claude', expected='y=', snapshot=fixture('claude'))
        with patch.object(clear.queue, 'identity', return_value=None):
            with self.assertRaises(clear.Refused):
                clear.prove(plan)
        with patch.object(clear.queue, 'identity', return_value=target), patch.dict(clear.LABEL, app=lambda *args: 'claude'), patch.object(clear, 'snapshot', return_value=dict(fixture('claude'), x=5)):
            with self.assertRaises(clear.Refused):
                clear.prove(plan)

    def test_expired_plan_refuses_without_target_access(self):
        import sys
        import uuid
        folder = Path.home() / 'desk/lab/clear-draft/proof-tests' / uuid.uuid4().hex
        folder.mkdir(parents=True)
        plan = folder / 'expired.plan'
        plan.write_text(json.dumps(dict(expires=0)))
        result = subprocess.run([sys.executable, str(ROOT / 'tools/relay-clear-draft'), '--prove', str(plan)], capture_output=True, timeout=3)
        self.assertEqual(result.returncode, 1)

    def test_invalid_pending_records_do_not_change_clear_outcome(self):
        import uuid
        folder = Path.home() / 'desk/lab/clear-draft/proof-tests' / uuid.uuid4().hex
        folder.mkdir(parents=True)
        (folder / 'malformed.json').write_text('{unreadable')
        self.assertEqual(clear.pending_count(folder, None), 'unknown')

    def test_copy_mode_snapshot_refuses(self):
        target = dict(socket='/socket', pane='%4', pid='100')
        state = '%4:1:4:9:178:56:100:0:config:claude:claude\n'
        with patch.object(clear, 'request', side_effect=[state, fixture('claude')['capture'], state]):
            with self.assertRaises(clear.Refused):
                clear.snapshot(target)

    def test_atomic_format_binds_draft_cursor_and_window(self):
        snap = fixture('claude')
        snap['fields'] = ['%4', '0', '4', '9', '178', '56', '100', '0', 'config', 'lab-clear-claude', '2.1.289']
        gate = clear.format_guard(dict(snapshot=snap, token='proof-token', expires=123))
        self.assertIn('#{cursor_x},4', gate)
        self.assertIn('#{window_name},lab-clear-claude', gate)
        self.assertIn('y=', gate)
        self.assertNotIn('send-keys', gate)
        self.assertIn('#{T:@relay_clear_clock}', gate)
        self.assertIn('#{e|<:', gate)
        self.assertIn('proof-token', gate)


if __name__ == '__main__':
    unittest.main()
