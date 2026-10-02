"""Regression: historical duplicates must not remove the active Enter row check."""
import pathlib
import subprocess
import tempfile
import os
import time
import unittest

GUARD = pathlib.Path(__file__).resolve().parents[1] / 'tools/relay-payload-guard'


class DuplicateEnterGuardTest(unittest.TestCase):
    def test_skip_row_still_binds_enter_to_active_payload(self):
        with tempfile.TemporaryDirectory() as directory:
            payload = pathlib.Path(directory, 'payload')
            payload.write_text('echo R3OLD', encoding='utf-8')
            result = subprocess.run(
                [str(GUARD), 'tmux-enter', str(payload), '›', '3',
                 '#{==:#{pane_id},%0}', '%0',
                 "send-keys -t %0 Enter ; display-message -p -t %0 delivered",
                 'display-message -p -t %0 refused', 'skip-row'],
                capture_output=True, text=True, check=True,
            )
            self.assertIn('#{C/r:', result.stdout,
                          'Enter must check the active composer even when history duplicates the payload')

    def test_duplicate_fallback_checks_current_row(self):
        socket = f"ccmsg-lab-private-{os.getpid()}"
        def tmux(*args):
            return subprocess.run(['tmux', '-L', socket, *args], capture_output=True, text=True)
        started = tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'lab-row', 'exec cat')
        self.assertEqual(started.returncode, 0, started.stderr)
        try:
            pane = tmux('list-panes', '-t', 'lab-row', '-F', '#{pane_id}').stdout.strip()
            socket_path = tmux('display-message', '-p', '-t', pane, '#{socket_path}').stdout.strip()
            self.assertTrue(pane.startswith('%'))
            tmux('send-keys', '-t', pane, '-l', '› old')
            tmux('send-keys', '-t', pane, 'Enter')
            tmux('send-keys', '-t', pane, '-l', '› new')
            with tempfile.TemporaryDirectory() as directory:
                old = pathlib.Path(directory, 'old')
                new = pathlib.Path(directory, 'new')
                old.write_text('old', encoding='utf-8')
                new.write_text('new', encoding='utf-8')
                for _ in range(50):
                    if '› new' in tmux('capture-pane', '-p', '-t', pane).stdout:
                        break
                    time.sleep(0.02)
                cursor_y = tmux('display-message', '-p', '-t', pane, '#{cursor_y}').stdout.strip()
                current = subprocess.run([str(GUARD), 'enter-row', socket_path, pane, '›', cursor_y, str(new)])
                changed = subprocess.run([str(GUARD), 'enter-row', socket_path, pane, '›', cursor_y, str(old)])
                self.assertEqual(current.returncode, 0)
                self.assertEqual(changed.returncode, 1)
        finally:
            tmux('kill-server')


if __name__ == '__main__':
    unittest.main()
