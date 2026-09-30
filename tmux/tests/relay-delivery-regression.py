#!/usr/bin/env python3
# path: ~/.config/tmux/tests/relay-delivery-regression.py
# description: Exercise public relays against real throwaway tmux terminals and hostile receivers.
# patched: cover payload fidelity, fail-closed transport, routing, and concurrent senders
# date: 2026-09-30
import argparse
import codecs
import json
import os
import pathlib
import select
import shlex
import subprocess
import sys
import tempfile
import time
import tty
import unicodedata


ROOT = pathlib.Path(__file__).resolve().parents[1]


def cells(text):
    return sum(0 if unicodedata.combining(c) else 2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in text)


def wrap(text, width):
    rows, row = [], ""
    for c in text:
        if cells(row + c) > width:
            rows.append(row)
            row = ""
        row += c
    return rows + [row]


def fixture(directory, glyph, mode):
    tty.setraw(sys.stdin.fileno())
    directory = pathlib.Path(directory)
    value = "user draft" if mode == "draft" else ""
    pending = b""
    decoder = codecs.getincrementaldecoder("utf-8")()
    pastes, submissions = [], []
    width, height = os.get_terminal_size()

    def draw():
        visible = value
        if mode == "hidden" and visible:
            visible = "[Pasted text #1]"
        lines = wrap(visible, width - 2)
        top = 3
        if len(lines) > max(1, height - 7):
            lines = lines[-max(1, height - 7):]
            first = "  "
        else:
            first = glyph + (" " if visible else "\u00a0")
        output = "\x1b[?2004h\x1b[2J\x1b[H"
        if mode == "startup-link":
            output += "\x1b]8;;https://chatgpt.com/codex\x1b\\Tip: Try Codex\x1b]8;;\x1b\\"
        if mode == "busy":
            output += "Working (1s · esc to interrupt)"
        if glyph == "❯":
            output += f"\x1b[{top};1H" + "─" * width
        for index, line in enumerate(lines):
            output += f"\x1b[{top + 1 + index};1H" + (first if index == 0 else "  ") + line
        if glyph == "❯":
            output += f"\x1b[{top + len(lines) + 1};1H" + "─" * width
        else:
            output += f"\x1b[{top + len(lines) + 1};1H\x1b[49m  \x1b[38;5;215mFast off · test · Context 0% used\x1b[39m"
        output += f"\x1b[{top + len(lines)};{2 + cells(lines[-1]) + 1}H"
        sys.stdout.write(output)
        sys.stdout.flush()
        (directory / "ready").touch()

    def insert(data):
        nonlocal value
        text = decoder.decode(data)
        if mode == "drop-prefix" and not pastes:
            text = text[10:]
        elif mode == "drop-boundary-space" and not pastes and text[190:191] == " ":
            text = text[:190] + text[191:]
        elif mode == "drop-suffix":
            text = text[:-1]
        elif mode == "tail-only":
            value = ""
            text = text[-30:]
        elif mode == "extra" and not pastes:
            text += "unexpected"
        elif mode == "mutate":
            text = text.replace("a", "b")
        value += text
        pastes.append(text)
        (directory / "landed.json").write_text(json.dumps(value, ensure_ascii=False))
        draw()

    draw()
    while True:
        if not select.select([sys.stdin], [], [], 10)[0]:
            continue
        data = os.read(sys.stdin.fileno(), 65536)
        if not data:
            return
        with (directory / "wire.bin").open("ab") as stream:
            stream.write(data)
        pending += data
        while pending:
            if pending.startswith(b"\x1b[200~"):
                end = pending.find(b"\x1b[201~", 6)
                if end < 0:
                    break
                if mode == "delay":
                    time.sleep(0.15)
                insert(pending[6:end])
                pending = pending[end + 6:]
            elif pending[:1] in (b"\r", b"\n"):
                submissions.append(value)
                (directory / "submitted.json").write_text(json.dumps(submissions, ensure_ascii=False))
                if mode != "ignore-enter":
                    value = ""
                pending = pending[1:]
                draw()
            elif b"\x1b[200~".startswith(pending):
                break
            else:
                newline = next((i for i, c in enumerate(pending) if c in (10, 13, 27)), len(pending))
                if newline == 0:
                    pending = pending[1:]
                else:
                    insert(pending[:newline])
                    pending = pending[newline:]


class Matrix:
    def __init__(self, output):
        self.output = pathlib.Path(output)
        self.output.mkdir(parents=True, exist_ok=True)
        self.results = []
        self.sessions = set()
        self.frozen = False
        self.number = 0
        self.socket = f"ccmsg-lab-private-{os.getpid()}"
        self.tmux_binary = self.output / "tmux-private"
        self.tmux_binary.write_text("#!/usr/bin/env bash\nexec tmux -L " + shlex.quote(self.socket) + ' -f /dev/null "$@"\n')
        self.tmux_binary.chmod(0o755)
        self.server_address = ""

    def tmux(self, *args):
        try:
            result = subprocess.run(["timeout", "2", str(self.tmux_binary), *args], capture_output=True, text=True, timeout=4)
        except subprocess.TimeoutExpired:
            self.frozen = True
            raise RuntimeError("tmux froze; stopped without recovery")
        if result.returncode in (124, 137, 143):
            self.frozen = True
            raise RuntimeError("tmux timed out; stopped without recovery")
        if result.returncode:
            raise RuntimeError(result.stderr)
        return result.stdout.strip()

    def start(self, relay, name, mode="idle", width=192, height=51):
        self.number += 1
        session = f"ccmsg-lab-{os.getpid()}-{self.number}"
        directory = self.output / f"{self.number:03d}-{relay}-{name}"
        directory.mkdir()
        glyph, window = ("❯", "claude") if relay == "cc-msg.sh" else ("›", "codex")
        command = shlex.join(["exec", sys.executable, str(pathlib.Path(__file__).resolve()), "--fixture", str(directory), glyph, mode])
        self.tmux("new-session", "-d", "-s", session, "-n", window, "-x", str(width), "-y", str(height), command)
        self.sessions.add(session)
        self.server_address = self.tmux("display-message", "-p", "-t", "=" + session + ":=" + window, "#{socket_path},#{pid},0")
        self.tmux("set-option", "-w", "-t", "=" + session + ":=" + window, "automatic-rename", "off")
        for _ in range(100):
            if (directory / "ready").exists():
                break
            time.sleep(0.02)
        else:
            raise RuntimeError("fixture failed to start")
        return session, window, directory

    def command(self, relay, session, window, payload, extra=None):
        env = {**os.environ, "CC_MSG_SESSION": session, "CC_MSG_WINDOW": window,
               "CODEX_SEND_SESSION": session, "CODEX_SEND_WINDOW": window,
               "TMUX": self.server_address, "TMUX_BIN": str(self.tmux_binary)}
        if extra:
            env.update(extra)
        argv = [str(ROOT / "tools" / relay)]
        if relay == "codex-send-to":
            argv.append(window)
        argv.append(payload)
        return argv, env

    def record(self, relay, name, result, expected_code, directory, expected_payload=None, no_input=False):
        time.sleep(0.05)
        submitted = json.loads((directory / "submitted.json").read_text()) if (directory / "submitted.json").exists() else []
        landed = json.loads((directory / "landed.json").read_text()) if (directory / "landed.json").exists() else ""
        passed = result.returncode == expected_code
        if expected_code == 0:
            passed = passed and submitted == [expected_payload]
        else:
            passed = passed and not submitted
        if no_input:
            passed = passed and not (directory / "wire.bin").exists()
        row = dict(relay=relay, case=name, passed=passed, exit=result.returncode, expected_exit=expected_code,
                   submitted_bytes=[len(s.encode()) for s in submitted], landed_bytes=len(landed.encode()),
                   expected_bytes=len(expected_payload.encode()) if expected_payload else 0,
                   stdout=result.stdout, stderr=result.stderr)
        self.results.append(row)
        (self.output / "matrix.json").write_text(json.dumps(self.results, indent=2))
        (directory / "result.json").write_text(json.dumps(row, indent=2))
        print(f"{'PASS' if passed else 'FAIL'} {relay} {name} exit={result.returncode}", flush=True)

    def case(self, relay, name, payload="relay payload", code=0, mode="idle", target=None, setup=None, extra=None, width=192, height=51):
        session, window, directory = self.start(relay, name, mode, width, height)
        try:
            if setup:
                setup(session, window)
            selected = target(session) if target else session
            argv, env = self.command(relay, selected, window, payload, extra)
            result = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=45)
            normalized = re_normalize(payload)
            expected = ("codex: " if relay == "cc-msg.sh" else "") + normalized
            self.record(relay, name, result, code, directory, expected, code in (1, 2, 5))
        finally:
            if not self.frozen:
                self.tmux("kill-session", "-t", "=" + session)
                self.sessions.discard(session)

    def concurrent(self, relay):
        session, window, directory = self.start(relay, "concurrent")
        try:
            message = "a" * 100
            argv, env = self.command(relay, session, window, message)
            first = subprocess.Popen(argv, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            time.sleep(0.08)
            second = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=45)
            stdout, stderr = first.communicate(timeout=45)
            result = subprocess.CompletedProcess(argv, first.returncode, stdout, stderr)
            expected = ("codex: " if relay == "cc-msg.sh" else "") + message
            self.record(relay, "concurrent-winner", result, 0, directory, expected)
            passed = second.returncode == 4 and "another relay" in second.stderr
            self.results.append(dict(relay=relay, case="concurrent-loser", passed=passed, exit=second.returncode,
                                     expected_exit=4, stdout=second.stdout, stderr=second.stderr))
            print(f"{'PASS' if passed else 'FAIL'} {relay} concurrent-loser exit={second.returncode}", flush=True)
        finally:
            if not self.frozen:
                self.tmux("kill-session", "-t", "=" + session)
                self.sessions.discard(session)

    def proxy_case(self, relay, name, action, code, no_input=False):
        session, window, directory = self.start(relay, name)
        try:
            proxy = directory / "tmux-proxy"
            trigger = directory / "triggered"
            target = "=" + session + ":=" + window
            real = shlex.quote(str(self.tmux_binary))
            chosen = shlex.quote(target)
            cases = {
                "timeout-list": 'if [ "$1" = list-panes ]; then exit 124; fi',
                "timeout-capture": f'if [ "$1" = capture-pane ] && [ -f {shlex.quote(str(trigger))} ]; then exit 124; fi\nif [ "$1" = if-shell ]; then touch {shlex.quote(str(trigger))}; fi',
                "bad-receipt": 'if [ "$1" = if-shell ]; then printf "__UNKNOWN__\\n"; exit 0; fi',
                "copy-before": f'if [ "$1" = if-shell ] && [ ! -f {shlex.quote(str(trigger))} ]; then {real} copy-mode -t {chosen}; touch {shlex.quote(str(trigger))}; fi',
                "copy-after": f'if [ "$1" = if-shell ]; then if [ -f {shlex.quote(str(trigger))} ]; then {real} copy-mode -t {chosen}; else touch {shlex.quote(str(trigger))}; fi; fi',
                "rename-before": f'if [ "$1" = if-shell ]; then {real} rename-window -t {chosen} changed; fi',
                "rename-enter": f'if [[ "$*" = *send-keys*Enter* ]]; then {real} rename-window -t {chosen} changed; fi',
                "copy-enter": f'if [[ "$*" = *send-keys*Enter* ]]; then {real} copy-mode -t {chosen}; fi',
            }
            proxy.write_text('#!/usr/bin/env bash\n' + cases[action] + f'\nexec {real} "$@"\n')
            proxy.chmod(0o755)
            argv, env = self.command(relay, session, window, "a" * 100, {"TMUX_BIN": str(proxy)})
            result = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=45)
            self.record(relay, name, result, code, directory, no_input=no_input)
        finally:
            if not self.frozen:
                self.tmux("kill-session", "-t", "=" + session)
                self.sessions.discard(session)

    def run(self):
        for relay in ("cc-msg.sh", "codex-send", "codex-send-to"):
            for size in (100, 1024, 1536, 4096, 16384, 65536):
                self.case(relay, f"size-{size}", "a" * size, 0 if size == 100 else 1)
            for name, payload in [
                ("utf8", "漢字 café em—dash 😀 " * 30),
                ("nbsp", "NBSP\u00a0inside and at\u00a0end"),
                ("whitespace", "\tstart\r\nsecond\tline\n  end \r\n"),
                ("shell-metacharacters", '- $ ` " \' \\ % ; $(touch /tmp/ccmsg-injected) ~'),
                ("footer-lookalike", "prefix " + "Fast off · test · Context 100% used"),
                ("divider-lookalike", "prefix " + "─" * 40),
                ("unbroken-unicode", "😀漢字" * 150),
            ]:
                self.case(relay, name, payload, 1 if name in ("utf8", "unbroken-unicode") else 0)
            self.case(relay, "utf8-C-locale", "漢字—😀" * 100, code=1, extra={"LC_ALL": "C"})
            for name, payload in [("empty", ""), ("only-whitespace", "\t\r\n "),
                                  ("escape-control", "bad\x1b[201~injection"), ("bidi-control", "bad\u202econtrol"),
                                  ("delete-control", "bad\x7fcontrol"), ("zero-width", "bad\u200bcontrol")]:
                self.case(relay, name, payload, 1)
            self.case(relay, "utf8-short", "漢字 café em—dash 😀 NBSP\u00a0inside")
            self.case(relay, "utf8-short-C-locale", "漢字—😀", extra={"LC_ALL": "C"})
            self.case(relay, "startup-tip-hyperlink", "Read /tmp/BRIEF.md and execute it end to end.", mode="startup-link")
            self.case(relay, "busy", "a" * 100, mode="busy")
            self.case(relay, "draft", mode="draft", code=5)
            self.case(relay, "copy-mode", code=2, setup=lambda s, w: self.tmux("copy-mode", "-t", "=" + s + ":=" + w))
            self.case(relay, "missing-session", code=1, target=lambda s: s + "-missing")
            self.case(relay, "wrong-case", code=1, target=lambda s: s.upper())
            self.case(relay, "duplicate-window", code=1,
                      setup=lambda s, w: self.tmux("new-window", "-d", "-t", "=" + s, "-n", w, "exec sleep 60"))
            self.case(relay, "dead-pane", code=1, setup=self.make_dead)
            self.case(relay, "bare-shell", code=1, setup=self.make_shell)
            for mode in ("drop-prefix", "drop-suffix", "tail-only", "extra", "mutate", "hidden"):
                self.case(relay, mode, "a" * 100, code=4, mode=mode)
            self.case(relay, "delayed-receiver", "a" * 100, mode="delay")
            self.case(relay, "drop-space-at-full-wrap", "a" * (183 if relay == "cc-msg.sh" else 190) + " " + "b" * 200,
                      code=1, mode="drop-boundary-space")
            self.case(relay, "tiny-pane", code=1, width=4, height=5)
            self.concurrent(relay)
            for name, code, no_input in [("timeout-list", 3, True), ("timeout-capture", 3, False),
                                         ("bad-receipt", 4, True), ("copy-before", 2, True),
                                         ("copy-after", 4, False), ("rename-before", 4, True),
                                         ("rename-enter", 4, False), ("copy-enter", 4, False)]:
                self.proxy_case(relay, name, name, code, no_input)
        (self.output / "matrix.json").write_text(json.dumps(self.results, indent=2))
        failures = sum(not row["passed"] for row in self.results)
        print(f"{len(self.results)} cases; {failures} failures; evidence: {self.output}")
        return 1 if failures else 0

    def make_dead(self, session, window):
        target = "=" + session + ":=" + window
        self.tmux("set-option", "-w", "-t", target, "remain-on-exit", "on")
        self.tmux("respawn-pane", "-k", "-t", target, "exit 0")
        time.sleep(0.1)

    def make_shell(self, session, window):
        self.tmux("respawn-pane", "-k", "-t", "=" + session + ":=" + window, "exec /bin/bash --noprofile --norc")
        time.sleep(0.1)


def re_normalize(text):
    import re
    return re.sub(" +", " ", text.replace("\r", " ").replace("\n", " ").replace("\t", " ")).strip(" ")


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "--fixture":
        fixture(*sys.argv[2:])
    else:
        parser = argparse.ArgumentParser()
        parser.add_argument("--output", default=None)
        args = parser.parse_args()
        matrix = Matrix(args.output or tempfile.mkdtemp(prefix="ccmsg-evidence-"))
        try:
            sys.exit(matrix.run())
        finally:
            if not matrix.frozen:
                for session in matrix.sessions.copy():
                    matrix.tmux("kill-session", "-t", "=" + session)
