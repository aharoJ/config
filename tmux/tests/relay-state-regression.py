#!/usr/bin/env python3
# path: ~/.config/tmux/tests/relay-state-regression.py
# description: Attack relay process, cursor, draft, and signal races on private tmux fixtures.
# patched: reproduce changed receivers and interrupted delivery without contacting agent panes
# date: 2026-09-30
import argparse
import codecs
import importlib.util
import json
import os
import pathlib
import select
import shlex
import signal
import shutil
import subprocess
import sys
import time
import tty

HERE = pathlib.Path(__file__).resolve()
spec = importlib.util.spec_from_file_location("delivery", HERE.with_name("relay-delivery-regression.py"))
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)
delivery.__file__ = str(HERE)


def fixture(directory, glyph, mode):
    directory = pathlib.Path(directory)
    tty.setraw(sys.stdin.fileno())
    value = ""
    pending = b""
    decoder = codecs.getincrementaldecoder("utf-8")()
    submitted = []
    width, height = os.get_terminal_size()

    def draw():
        spacer = " " if value else "\u00a0"
        if glyph == "❯":
            screen = "─" * width + "\r\n❯" + spacer + value + "\r\n" + "─" * width
            row = 2
        else:
            screen = "›" + spacer + value + "\r\n\r\n  Fast off · GPT-6.1-Sol high · ~/lab · Context 0% used"
            row = 1
        sys.stdout.write("\x1b[?2004h\x1b[2J\x1b[H" + screen + f"\x1b[{row};{delivery.cells(value) + 3}H")
        sys.stdout.flush()
        (directory / "ready").touch()

    draw()
    while True:
        control = directory / "control.json"
        if control.exists():
            operation = json.loads(control.read_text())
            control.unlink()
            value = operation["value"]
            (directory / "landed.json").write_text(json.dumps(value))
            draw()
            (directory / "controlled").touch()
        if not select.select([sys.stdin], [], [], 0.01)[0]:
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
                value += decoder.decode(pending[6:end])
                (directory / "landed.json").write_text(json.dumps(value))
                pending = pending[end + 6:]
            elif pending[:1] in (b"\r", b"\n"):
                submitted.append(value)
                (directory / "submitted.json").write_text(json.dumps(submitted))
                value = ""
                pending = pending[1:]
            elif b"\x1b[200~".startswith(pending):
                break
            else:
                pending = pending[1:]
            draw()


class StateMatrix(delivery.Matrix):
    def race(self, relay, action):
        session, window, directory = self.start(relay, action)
        try:
            target = self.tmux("display-message", "-p", "-t", "=" + session + ":=" + window, "#{pane_id}")
            real = shlex.quote(str(self.tmux_binary))
            marker = shlex.quote(str(directory / "triggered"))
            selected = "paste-buffer" if action.endswith("paste") else "send-keys"
            if action.startswith("respawn"):
                glyph = "❯" if relay == "cc-msg.sh" else "›"
                command = shlex.join(["exec", sys.executable, str(HERE), "--fixture", str(directory), glyph, "idle"])
                operation = f'rm -f {shlex.quote(str(directory / "ready"))}; {real} respawn-pane -k -t {target} {shlex.quote(command)}; '
                operation += f'for n in {{1..100}}; do test -f {shlex.quote(str(directory / "ready"))} && break; /bin/sleep 0.01; done'
            elif action.startswith("resize"):
                operation = f'{real} resize-window -t {target} -x 80 -y 51'
            else:
                value = "user draft" if action.endswith("paste") else ("relay: " if relay == "cc-msg.sh" else "") + ("b" * 100 if action.startswith("same-draft") else "a" * 100 + "x")
                control = directory / "control.json"
                staged = directory / "staged.json"
                staged.write_text(json.dumps({"value": value}))
                operation = f'mv {shlex.quote(str(staged))} {shlex.quote(str(control))}; '
                operation += f'for n in {{1..100}}; do test -f {shlex.quote(str(directory / "controlled"))} && break; /bin/sleep 0.01; done'
            proxy = directory / "tmux-race"
            proxy.write_text(f'#!/usr/bin/env bash\nif {{ [ "$1" = if-shell ] || [ "$1" = source-file ]; }} && [[ "$*" = *{selected}* ]] && [ ! -f {marker} ]; then touch {marker}; {operation}; fi\nexec {real} "$@"\n')
            proxy.chmod(0o755)
            argv, env = self.command(relay, session, window, "a" * 100, {"TMUX_BIN": str(proxy)})
            result = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=20)
            self.record(relay, action, result, 4, directory, no_input=action.endswith("paste"))
        finally:
            if not self.frozen:
                self.cleanup_session(session)

    def interrupted(self, relay, stage, signum):
        name = f"signal-{stage}-{signal.Signals(signum).name}"
        session, window, directory = self.start(relay, name)
        try:
            real = shlex.quote(str(self.tmux_binary))
            marker = directory / "signal-ready"
            selected = {"list": '[ "$1" = list-panes ]', "load": '[ "$1" = load-buffer ]', "paste": '[ "$1" = if-shell ] && [[ "$*" = *paste-buffer* ]]',
                        "compare": '[ "$1" = capture-pane ] && [ -f ' + shlex.quote(str(directory / "pasted")) + ' ]',
                        "enter": '{ [ "$1" = if-shell ] || [ "$1" = source-file ]; } && [[ "$*" = *send-keys* ]]'}[stage]
            proxy = directory / "tmux-signal"
            proxy.write_text(f'#!/usr/bin/env bash\nif [ "$1" = if-shell ] && [[ "$*" = *paste-buffer* ]]; then touch {shlex.quote(str(directory / "pasted"))}; fi\nif {selected} && [ ! -f {shlex.quote(str(marker))} ]; then {real} "$@"; code=$?; touch {shlex.quote(str(marker))}; /bin/sleep 0.3; exit "$code"; fi\nexec {real} "$@"\n')
            proxy.chmod(0o755)
            argv, env = self.command(relay, session, window, "a" * 100, {"TMUX_BIN": str(proxy)})
            child = subprocess.Popen(argv, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                deadline = time.monotonic() + 8
                while not marker.exists() and child.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.01)
                if not marker.exists():
                    raise RuntimeError("signal stage was not reached")
                child.send_signal(signum)
                stdout, stderr = child.communicate(timeout=8)
            finally:
                if child.poll() is None:
                    child.kill()
                    child.communicate()
            passed = child.returncode == (1 if stage in ("list", "load") else 4) and "interrupt" in stderr.lower()
            submitted = json.loads((directory / "submitted.json").read_text()) if (directory / "submitted.json").exists() else []
            passed = passed and (len(submitted) == 1 if stage == "enter" else not submitted)
            buffers = self.tmux("list-buffers", "-F", "#{buffer_name}")
            passed = passed and not buffers
            row = dict(relay=relay, case=name, passed=passed, exit=child.returncode, stdout=stdout, stderr=stderr, submitted=submitted)
            self.results.append(row)
            (self.output / "matrix.json").write_text(json.dumps(self.results, indent=2))
            print(f"{'PASS' if passed else 'FAIL'} {relay} {name} exit={child.returncode}", flush=True)
        finally:
            if not self.frozen:
                self.cleanup_session(session)

    def invocation(self, relay, shell):
        session, window, directory = self.start(relay, "invoke-" + shell)
        try:
            alias = directory / "relay link"
            alias.symlink_to(delivery.ROOT / "tools" / relay)
            argv, env = self.command(relay, session, window, "- #{pane_id} $ ` ; 漢字")
            argv[0] = str(alias)
            if shell == "fish":
                argv = [shutil.which(shell), "--no-config", "-c", "command $argv", *argv]
            elif shell == "zsh":
                argv = [shutil.which(shell), "-f", "-c", '"$@"', "relay-test", *argv]
            else:
                argv = [shutil.which(shell), "--noprofile", "--norc", "-c", '"$@"', "relay-test", *argv]
            cwd = directory / "odd $ ; working directory"
            cwd.mkdir()
            result = subprocess.run(argv, env=env, cwd=cwd, capture_output=True, text=True, timeout=20)
            expected = ("relay: " if relay == "cc-msg.sh" else "") + "- #{pane_id} $ ` ; 漢字"
            self.record(relay, "invoke-" + shell, result, 0, directory, expected)
        finally:
            if not self.frozen:
                self.cleanup_session(session)

    def extra_arguments(self, relay):
        session, window, directory = self.start(relay, "extra-arguments")
        try:
            argv, env = self.command(relay, session, window, "first")
            result = subprocess.run(argv + ["silently dropped"], env=env, capture_output=True, text=True, timeout=20)
            self.record(relay, "extra-arguments", result, 1, directory, no_input=True)
        finally:
            if not self.frozen:
                self.cleanup_session(session)

    def degraded(self, relay, action):
        session, window, directory = self.start(relay, action)
        try:
            real = shlex.quote(str(self.tmux_binary))
            proxy = directory / "tmux-degraded"
            if action == "slow-request":
                source = f'if [ "$1" = list-panes ]; then /bin/sleep 2; fi\nexec {real} "$@"'
                expected, no_input = 3, True
            else:
                source = f'if [ "$1" = if-shell ] && [[ "$*" = *paste-buffer* ]]; then {real} "$@"; code=$?; {real} kill-server; exit "$code"; fi\nexec {real} "$@"'
                expected, no_input = 4, False
            proxy.write_text("#!/usr/bin/env bash\n" + source + "\n")
            proxy.chmod(0o755)
            argv, env = self.command(relay, session, window, "a" * 100, {"TMUX_BIN": str(proxy)})
            result = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=10)
            self.record(relay, action, result, expected, directory, no_input=no_input)
        finally:
            if action == "server-death":
                self.sessions.discard(session)
            elif not self.frozen:
                self.cleanup_session(session)

    def run_stress(self, group):
        for relay in ("cc-msg.sh", "codex-send", "codex-send-to"):
            if group in ("all", "races"):
                for action in ("respawn-paste", "respawn-enter", "draft-paste", "draft-enter", "resize-enter"):
                    self.race(relay, action)
            if group in ("all", "signals"):
                for stage in ("list", "load", "paste", "compare", "enter"):
                    for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGPIPE):
                        self.interrupted(relay, stage, signum)
            if group in ("all", "invocation"):
                for shell in ("bash", "fish", "zsh"):
                    self.invocation(relay, shell)
                if relay != "cc-msg.sh":
                    self.extra_arguments(relay)
                self.case(relay, "missing-TMUX", code=1, extra={"TMUX": ""})
                for action in ("slow-request", "server-death"):
                    self.degraded(relay, action)
        failures = sum(not row["passed"] for row in self.results)
        print(f"{len(self.results)} cases; {failures} failures; evidence: {self.output}")
        return int(bool(failures))


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "--fixture":
        fixture(*sys.argv[2:])
    else:
        parser = argparse.ArgumentParser()
        parser.add_argument("--output", required=True)
        parser.add_argument("--group", choices=("all", "races", "signals", "invocation"), default="all")
        args = parser.parse_args()
        matrix = StateMatrix(args.output)
        try:
            sys.exit(matrix.run_stress(args.group))
        finally:
            matrix.close()
