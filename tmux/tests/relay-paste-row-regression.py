#!/usr/bin/env python3
# path: ~/.config/tmux/tests/relay-paste-row-regression.py
# description: Exercise atomic paste row guards on a private tmux server.
import os
import pathlib
import re
import shlex
import subprocess
import sys
import tempfile
import time


ROOT = pathlib.Path(__file__).resolve().parents[1]
GUARD = ROOT / "tools/relay-payload-guard"
TMUX = "tmux"


def run(*args, check=True):
    result = subprocess.run([TMUX, "-L", SOCKET, "-f", "/dev/null", *args],
                            capture_output=True, text=True, timeout=4)
    if check and result.returncode:
        raise AssertionError((args, result.returncode, result.stderr))
    return result.stdout.strip()


def visible_rows(capture):
    return [re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", row) for row in capture.splitlines()]


def wait_for(pane, marker):
    for _ in range(50):
        capture = run("capture-pane", "-p", "-e", "-t", pane)
        if marker in capture:
            return capture
        time.sleep(0.1)
    raise AssertionError(f"private pane {pane} did not render {marker!r}")


def paste_guard(capture, glyph, cursor_y, path):
    path.write_text(capture)
    result = subprocess.run([str(GUARD), "tmux-paste", str(path), glyph, str(cursor_y)],
                            capture_output=True, text=True, timeout=4)
    assert result.returncode == 0, (result.returncode, result.stderr, repr(capture[:500]), cursor_y)
    return result.stdout


def pane_state(pane):
    return run("display-message", "-p", "-t", pane, "#{pane_id}:#{cursor_x}:#{cursor_y}")


def evaluate(pane, expression):
    return run("display-message", "-p", "-t", pane, expression)


def main():
    global SOCKET
    SOCKET = f"relay-paste-row-private-{os.getpid()}"
    scratch = pathlib.Path(tempfile.mkdtemp(prefix="relay-paste-row-"))
    fifo = scratch / "redraw.fifo"
    os.mkfifo(fifo)
    pane_program = scratch / "pane.py"
    pane_program.write_text('''import os, sys
fifo, kind = sys.argv[1:]
if kind == "codex":
    os.write(1, "\\x1b[2J\\x1b[H\\x1b[1m›\\x1b[0m \\x1b[2mContinue the dim hint\\x1b[0m\\r\\n\\x1b[2m  wrapped line alpha\\x1b[0m\\r\\n  \\x1b[38;5;183mFast off\\x1b[39m · test · Context 0% used\\x1b[1;3H".encode())
    while True:
        with open(fifo) as stream:
            for command in stream:
                if command.strip() == "alter":
                    os.write(1, "\\x1b[2;1H\\x1b[2m  wrapped line bravo\\x1b[0m\\x1b[1;3H".encode())
else:
    divider = "─" * 100
    os.write(1, ("\\x1b[2J\\x1b[H" + divider + "\\r\\n>\\r\\n" + divider + "\\r\\n? for shortcuts\\x1b[2;3H").encode())
    with open(fifo) as stream:
        for _ in stream:
            pass
''')
    try:
        command = f"exec {shlex.quote(sys.executable)} -u {shlex.quote(str(pane_program))} {shlex.quote(str(fifo))} codex"
        run("new-session", "-d", "-s", "row", "-n", "codex", "-x", "100", "-y", "20", command)
        codex_pane = run("list-panes", "-t", "=row:=codex", "-F", "#{pane_id}")
        before = wait_for(codex_pane, "wrapped line alpha")
        state_before = pane_state(codex_pane)
        expression = paste_guard(before, "›", state_before.split(":")[2], scratch / "codex.capture")
        assert evaluate(codex_pane, expression) == "1", "original wrapped dim rows refused"
        with open(fifo, "w") as stream:
            stream.write("alter\n")
        after = wait_for(codex_pane, "wrapped line bravo")
        state_after = pane_state(codex_pane)
        assert state_after == state_before, (state_before, state_after)
        old_rows, new_rows = visible_rows(before), visible_rows(after)
        changed = [index for index, (old, new) in enumerate(zip(old_rows, new_rows)) if old != new]
        assert len(old_rows) == len(new_rows) and changed == [1], changed
        assert evaluate(codex_pane, expression) == "0", "changed continuation passed paste guard"

        command = f"exec {shlex.quote(sys.executable)} -u {shlex.quote(str(pane_program))} {shlex.quote(str(fifo))} agy"
        run("new-window", "-d", "-t", "row", "-n", "agy", command)
        agy_pane = run("list-panes", "-t", "=row:=agy", "-F", "#{pane_id}")
        agy = wait_for(agy_pane, "? for shortcuts")
        agy_state = pane_state(agy_pane)
        agy_expression = paste_guard(agy, ">", agy_state.split(":")[2], scratch / "agy.capture")
        assert evaluate(agy_pane, agy_expression) == "1", "empty Agy prompt refused"
        print("relay paste row regression: PASS")
    finally:
        run("kill-server", check=False)
        subprocess.run(["trash", str(scratch)], check=True)


if __name__ == "__main__":
    main()
