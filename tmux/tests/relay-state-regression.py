#!/usr/bin/env python3
# path: ~/.config/tmux/tests/relay-state-regression.py
# description: Attack relay process, cursor, draft, and signal races on private tmux fixtures.
# patched: render Claude's required status and mode footer in race fixtures
# date: 2026-10-02T04:00:00Z
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
    home = False
    pending = b""
    decoder = codecs.getincrementaldecoder("utf-8")()
    submitted = []
    width, height = os.get_terminal_size()

    def draw():
        spacer = " " if value else "\u00a0"
        if glyph in ("❯", ">"):
            screen = "─" * width + "\r\n❯" + spacer + value + "\r\n" + "─" * width + "\r\n  Opus 5.5 | v2.1.287\r\n  ⏵⏵ bypass permissions on"
            if glyph == ">":
                divider = "\x1b[38;5;244m" + "─" * width + "\x1b[39m"
                prompt = "\x1b[94m>\x1b[39m" + (" " + value if value else "")
                screen = divider + "\r\n" + prompt + "\r\n" + divider + "\r\n\x1b[38;5;246m? for shortcuts  Gemini 3.8 Flash · high\x1b[39m"
            row = 2
        else:
            composer = "› " + value if value else "\x1b[1m›\x1b[0m \x1b[2mAsk Codex to do anything\x1b[0m"
            screen = composer + "\r\n\r\n  Fast off · GPT-6.1-Sol high · ~/lab · Context 0% used"
            row = 1
        sys.stdout.write("\x1b[?2004h\x1b[2J\x1b[H" + screen + f"\x1b[{row};{3 if home else delivery.cells(value) + 3}H")
        sys.stdout.flush()
        (directory / "ready").touch()

    draw()
    while True:
        control = directory / "control.json"
        if control.exists():
            operation = json.loads(control.read_text())
            control.unlink()
            value = operation["value"]
            home = bool(operation.get("home", False))
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
    def start(self, relay, name, mode="idle", width=192, height=51):
        if relay != "agy-send-to":
            return super().start(relay, name, mode, width, height)
        self.number += 1
        session = f"lab-ccmsg-{os.getpid()}-{self.number}"
        directory = self.output / f"{self.number:03d}-{relay}-{name}"
        directory.mkdir()
        agy_binary = self.output / "agy"
        if not agy_binary.exists():
            shutil.copy2(sys.executable, agy_binary)
        command = shlex.join(["exec", str(agy_binary), str(HERE), "--fixture", str(directory), ">", mode])
        self.tmux("new-session", "-d", "-s", session, "-n", "lab-agy", "-x", str(width), "-y", str(height), command)
        self.sessions.add(session)
        self.server_address = self.tmux("display-message", "-p", "-t", "=" + session + ":=lab-agy", "#{socket_path},#{pid},0")
        self.tmux("set-option", "-w", "-t", "=" + session + ":=lab-agy", "automatic-rename", "off")
        for _ in range(100):
            if (directory / "ready").exists():
                break
            time.sleep(0.02)
        else:
            raise RuntimeError("Agy fixture failed to start")
        return session, "lab-agy", directory

    def command(self, relay, session, window, payload, extra=None):
        if relay != "agy-send-to":
            return super().command(relay, session, window, payload, extra)
        env = {**os.environ, "AGY_SEND_SESSION": session, "TMUX": self.server_address,
               "TMUX_BIN": str(self.tmux_binary), "TMUX_RELAY_LOCK_ROOT": str(self.output / "relay-locks")}
        if extra:
            env.update(extra)
        return [str(delivery.ROOT / "tools/agy-send-to"), window, payload], env

    def display_fallback(self, relay, action):
        session, window, directory = self.start(relay, "display-" + action)
        replacement = directory / "replacement"
        replacement.mkdir()
        alpha = directory / "alpha"
        alpha.mkdir()
        glyph = "❯" if relay == "cc-msg.sh" else ">" if relay == "agy-send-to" else "›"
        replacement_command = shlex.join(["exec", sys.executable, str(HERE), "--fixture", str(replacement), glyph, "idle"])
        alpha_command = shlex.join(["exec", sys.executable, str(HERE), "--fixture", str(alpha), glyph, "idle"])
        target = "=" + session + ":=" + window
        try:
            self.tmux("new-window", "-d", "-t", "=" + session, "-n", "alpha", alpha_command)
            self.tmux("set-option", "-w", "-t", "=" + session + ":=alpha", "automatic-rename", "off")
            for _ in range(100):
                if (alpha / "ready").exists():
                    break
                time.sleep(0.02)
            else:
                raise RuntimeError("fallback alpha fixture failed to start")
            self.tmux("select-window", "-t", "=" + session + ":=alpha")
            victim_pane = self.tmux("display-message", "-p", "-t", target, "#{pane_id}")
            fallback = self.tmux("display-message", "-p", "-t", "=" + session + ":=missing", "#{pane_id}")
            real = shlex.quote(str(self.tmux_binary))
            marker = shlex.quote(str(directory / "triggered"))
            if action == "missing-window":
                trigger = '[ "$1" = display-message ] && [[ "$*" = *pane_width* ]] && [[ "$*" = *pane_pid* ]]'
                effect = f'{real} kill-window -t {shlex.quote(target)}'
                expected, no_input = 1, True
            elif action == "paste-receipt":
                trigger = '[ "$1" = if-shell ] && [[ "$*" = *paste-buffer* ]]'
                effect = "printf '%s\\n' '__RELAY_DELIVERED__:%99999'"
                expected, no_input = 4, True
            elif action == "enter-receipt":
                trigger = '[ "$1" = source-file ]'
                effect = "printf '%s\\n' '__RELAY_DELIVERED__:%99999'"
                expected, no_input = 4, False
            else:
                trigger = '[ "$1" = source-file ]'
                effect = f'{real} kill-window -t {shlex.quote(target)}; {real} new-window -d -t {shlex.quote("=" + session)} -n {shlex.quote(window)} {shlex.quote(replacement_command)}'
                expected, no_input = 4, False
            proxy = directory / "tmux-fallback"
            proxy.write_text(f'#!/usr/bin/env bash\nif {trigger} && [ ! -e {marker} ]; then : > {marker}; {effect};'
                             f'\n  if [ "$?" != 0 ]; then exit 98; fi\n  if [ "{action}" = paste-receipt ] || [ "{action}" = enter-receipt ]; then exit 0; fi\nfi\nexec {real} "$@"\n')
            proxy.chmod(0o755)
            argv, env = self.command(relay, session, window, "display fallback inert probe", {"TMUX_BIN": str(proxy)})
            result = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=30)
            self.record(relay, "display-" + action, result, expected, directory, no_input=no_input)
            replacement_wire = (replacement / "wire.bin").stat().st_size if (replacement / "wire.bin").exists() else 0
            alpha_wire = (alpha / "wire.bin").stat().st_size if (alpha / "wire.bin").exists() else 0
            passed = fallback != victim_pane and fallback.startswith("%") and (directory / "triggered").exists() and replacement_wire == 0 and alpha_wire == 0
            self.results.append(dict(relay=relay, case="display-" + action + "-identity", passed=passed,
                                     fallback_pane=fallback, victim_pane=victim_pane, alpha_wire=alpha_wire,
                                     replacement_wire=replacement_wire))
            print(f"{'PASS' if passed else 'FAIL'} {relay} display-{action}-identity", flush=True)
        finally:
            if not self.frozen:
                self.cleanup_session(session)

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
                value = ("Q" if action == "home-draft-paste" else "user draft") if action.endswith("paste") else ("relay: " if relay == "cc-msg.sh" else "") + ("b" * 100 if action.startswith("same-draft") else "a" * 100 + "x")
                control = directory / "control.json"
                staged = directory / "staged.json"
                staged.write_text(json.dumps({"value": value, "home": action == "home-draft-paste"}))
                operation = f'mv {shlex.quote(str(staged))} {shlex.quote(str(control))}; '
                operation += f'for n in {{1..100}}; do test -f {shlex.quote(str(directory / "controlled"))} && break; /bin/sleep 0.01; done'
            proxy = directory / "tmux-race"
            proxy.write_text(f'#!/usr/bin/env bash\nif {{ [ "$1" = if-shell ] || [ "$1" = source-file ]; }} && [[ "$*" = *{selected}* ]] && [ ! -f {marker} ]; then touch {marker}; {operation}; fi\nexec {real} "$@"\n')
            proxy.chmod(0o755)
            argv, env = self.command(relay, session, window, "a" * 100, {"TMUX_BIN": str(proxy)})
            result = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=20)
            expected = 1 if action == "respawn-paste" else 5 if action in ("draft-paste", "home-draft-paste") else 4
            self.record(relay, action, result, expected, directory, no_input=action.endswith("paste"))
            if action == "home-draft-paste":
                passed = (directory / "triggered").exists() and json.loads((directory / "landed.json").read_text()) == "Q" and not (directory / "wire.bin").exists()
                self.results.append(dict(relay=relay, case=action + "-staged", passed=passed))
                print(f"{'PASS' if passed else 'FAIL'} {relay} {action}-staged", flush=True)
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
        if group == "fallback":
            for relay in ("cc-msg.sh", "codex-send", "codex-send-to", "agy-send-to"):
                for action in ("missing-window", "paste-receipt", "enter-receipt", "enter-replace"):
                    self.display_fallback(relay, action)
            failures = sum(not row["passed"] for row in self.results)
            print(f"{len(self.results)} cases; {failures} failures; evidence: {self.output}")
            return int(bool(failures))
        for relay in ("cc-msg.sh", "codex-send", "codex-send-to"):
            if group in ("all", "races"):
                for action in ("respawn-paste", "respawn-enter", "draft-paste", "draft-enter", "same-draft-enter", "resize-enter"):
                    self.race(relay, action)
                if relay == "cc-msg.sh":
                    self.race(relay, "home-draft-paste")
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
        parser.add_argument("--group", choices=("all", "races", "signals", "invocation", "fallback"), default="all")
        args = parser.parse_args()
        matrix = StateMatrix(args.output)
        try:
            sys.exit(matrix.run_stress(args.group))
        finally:
            matrix.close()
