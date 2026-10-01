#!/usr/bin/env python3
# path: ~/.config/tmux/tests/tool-stress-regression.py
# description: Attack watcher invocation, incident boundaries, and status fallbacks without live tmux.
# patched: pin hostile invocation, socket escape, timeout, and permission behavior
# date: 2026-10-01
import os
import pathlib
import socket
import shutil
import subprocess
import tempfile
import time
import unittest
import sys
import hashlib
import importlib.util
import signal

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ToolStress(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="tmux-tool-stress-", dir="/private/tmp")
        self.addCleanup(self.scratch.cleanup)
        self.directory = pathlib.Path(self.scratch.name)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        self.env = {**os.environ, "TMPDIR": str(self.directory), "PATH": str(self.bin) + os.pathsep + os.environ["PATH"]}
        self.env.pop("TMUX", None)
        self.env.pop("TMUX_PANE", None)
        for name in ("tmux", "lsof", "sample", "lldb", "llvm-objdump", "dwarfdump"):
            stub = self.executable(name, "exit 1")
            self.env["TMUX_LOOP_RESCUE_" + {"tmux": "TMUX", "lsof": "LSOF", "sample": "SAMPLE", "lldb": "LLDB", "llvm-objdump": "OBJDUMP", "dwarfdump": "DWARFDUMP"}[name] + "_BIN"] = str(stub)

    def executable(self, name, source):
        path = self.bin / name
        audit = 'if [ -n "${STRESS_OFFLINE_AUDIT_LOG:-}" ]; then ' + str(pathlib.Path(sys.executable)) + ' -c \'import json,os,sys; open(os.environ["STRESS_OFFLINE_AUDIT_LOG"],"a").write(json.dumps({"backend":"offline-stub","argv":sys.argv[1:]})+"\\n")\' ' + '"$0" "$@"; fi\n'
        path.write_text("#!/usr/bin/env bash\n" + audit + source + "\n")
        path.chmod(0o755)
        return path

    def run_tool(self, name, *args, extra=None, timeout=3, umask=0o022):
        env = {**self.env, **(extra or {})}
        with tempfile.TemporaryFile() as output:
            process = subprocess.Popen([str(ROOT / "tools" / name), *args], env=env, stdout=output,
                                       stderr=subprocess.STDOUT, umask=umask, start_new_session=True)
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, 9)
                process.wait()
                self.fail(f"{name} hung with {args!r}")
            output.seek(0)
            return process.returncode, output.read().decode(errors="replace")

    def socket(self, name):
        path = self.directory / name
        server = socket.socket(socket.AF_UNIX)
        self.addCleanup(server.close)
        server.bind(str(path))
        return path

    def test_watcher_missing_values(self):
        for flag in ("--pane", "--ui", "--hot-file"):
            with self.subTest(flag=flag):
                code, output = self.run_tool("pane-watch/pane-watch.sh", flag, timeout=0.5)
                self.assertEqual(code, 64, output)

    def test_default_server_is_never_forwarded(self):
        calls = self.directory / "backend-calls"
        backend = self.executable("reachable-backend", 'printf "%s\\n" "$*" >> "$BACKEND_CALLS"\nexit 0')
        env = {**self.env, "STRESS_REAL_TMUX": str(backend), "STRESS_TMUX_AUDIT_LOG": str(self.directory / "audit"),
               "STRESS_PRIVATE_SOCKET": "ccmsg-lab-private-12345", "TMUX": "/private/tmp/tmux-501/default,1,0",
               "BACKEND_CALLS": str(calls)}
        control = subprocess.run([str(backend), "-L", "default", "ls"], env=env, capture_output=True, timeout=2)
        self.assertEqual(control.returncode, 0)
        calls.unlink()
        for args in (("ls",), ("-L", "default", "-f", "/dev/null", "ls"), ("-S", "/private/tmp/tmux-501/default", "ls")):
            result = subprocess.run(["python3", str(ROOT / "tests/private-tmux-guard.py"), *args], env=env,
                                    capture_output=True, timeout=2)
            self.assertEqual(result.returncode, 97, result.stderr)
            self.assertFalse(calls.exists())
        env["TMUX"] = "/private/tmp/tmux-501/ccmsg-lab-private-12345,1,0"
        result = subprocess.run(["python3", str(ROOT / "tests/private-tmux-guard.py"), "ls"], env=env,
                                capture_output=True, timeout=2)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls.read_text(), "-L ccmsg-lab-private-12345 -f /dev/null ls\n")

    def test_live_capture_rejects_default_before_tmux(self):
        marker = self.directory / "called"
        self.executable("tmux", 'touch "$DEFAULT_CALL_MARKER"; exit 0')
        result = subprocess.run(["bash", str(ROOT / "tests/relay-live-capture-regression.sh")],
                                env={**self.env, "TMUX": "/private/tmp/tmux-501/default,1,0", "DEFAULT_CALL_MARKER": str(marker)},
                                capture_output=True, text=True, timeout=2)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse(marker.exists())

    def test_fixture_runner_refuses_missing_fake_tmux(self):
        source = ROOT / "tools/pane-watch/tests/run"
        clone = self.directory / "runner"
        clone.mkdir()
        shutil.copyfile(source, clone / "run")
        marker = self.directory / "called"
        self.executable("tmux", 'touch "$DEFAULT_CALL_MARKER"; exit 0')
        result = subprocess.run(["bash", str(clone / "run"), str(ROOT / "tools/pane-watch/pane-watch.sh"), "real_geometry"],
                                env={**self.env, "DEFAULT_CALL_MARKER": str(marker)}, capture_output=True, text=True, timeout=4)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse(marker.exists())

    def test_fixture_runner_removes_state(self):
        source = ROOT / "tools/pane-watch/tests"
        clone = self.directory / "runner"
        clone.mkdir()
        shutil.copyfile(source / "run", clone / "run")
        shutil.copytree(source / "fakebin", clone / "fakebin")
        shutil.copytree(source / "fx/real_geometry", clone / "fx/real_geometry")
        result = subprocess.run(["bash", str(clone / "run"), str(ROOT / "tools/pane-watch/pane-watch.sh"), "real_geometry", "--ack-current"],
                                env=self.env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ARMED codex", result.stdout)
        self.assertFalse((clone / ".tmp").exists())
        self.assertFalse(list(self.directory.glob("pane-watch-fixture.*")))

    def test_delivery_harness_cleans_after_failure(self):
        spec = importlib.util.spec_from_file_location("delivery_cleanup", ROOT / "tests/relay-delivery-regression.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for signum in (signal.SIGINT, signal.SIGTERM):
            self.addCleanup(signal.signal, signum, signal.getsignal(signum))
        matrix = module.Matrix(self.directory / "matrix")
        matrix.frozen = True
        matrix.tmux_binary = self.executable("owned-private-tmux", 'case "$1" in kill-server) exit 0 ;; ls) exit 1 ;; esac')
        sock = self.socket(matrix.socket)
        matrix.server_address = str(sock) + ",123,0"
        matrix.close()
        self.assertFalse(sock.exists())
        self.assertTrue((matrix.output / "cleanup.json").exists())

    def test_watcher_flag_as_value(self):
        code, output = self.run_tool("pane-watch/pane-watch.sh", "--pane", "--ui", "codex")
        self.assertEqual(code, 64, output)
        self.assertIn("requires a value", output)

    def watcher_stub(self):
        self.executable("tmux", '''case "$1" in
display-message)
 case "${!#}" in
 '#{pane_id}') echo %13 ;;
 '#{pane_height}') echo 59 ;;
 '#{pane_height}:#{pid}:#{pane_pid}')
  count=0; [ ! -f "$TMPDIR/height-count" ] || count=$(cat "$TMPDIR/height-count")
  count=$((count + 1)); echo "$count" > "$TMPDIR/height-count"
  if [ "${WATCH_TEST_REPLACE:-0}" = 1 ] && [ "$count" -gt 3 ]; then echo 59:999:101; else echo 59:999:100; fi ;;
 '#{pid}:#{pane_pid}') echo 999:100 ;;
 '#{socket_path}') echo "${WATCH_TEST_SOCKET:-/tmp/watch-test.socket}" ;;
 *) echo '0 node lab-test lab-codex /tmp/project' ;;
 esac ;;
list-panes) echo %13 ;;
capture-pane) printf '%s\\n' '› operation' '• Finished.' '› Ask Codex to do anything' '' '  Fast off · test · Context 0% used' ;;
*) exit 1 ;;
esac''')

    def test_watcher_invalid_intervals(self):
        self.watcher_stub()
        for setting in ("PW_POLL", "PW_NOREPLY", "PW_HEARTBEAT"):
            for value in ("bad", "-1", "0.5", "08"):
                with self.subTest(setting=setting, value=value):
                    code, output = self.run_tool("pane-watch/pane-watch.sh", "--pane", "%13", "--ui", "codex",
                                                 extra={setting: value}, timeout=0.5)
                    self.assertEqual(code, 64, output)

    def test_watcher_lock_binds_server(self):
        self.watcher_stub()
        children = []
        outputs = []
        try:
            for server in ("one", "two"):
                output = tempfile.TemporaryFile()
                outputs.append(output)
                child = subprocess.Popen([str(ROOT / "tools/pane-watch/pane-watch.sh"), "--pane", "%13", "--ui", "codex", "--ack-current"],
                                         env={**self.env, "WATCH_TEST_SOCKET": "/tmp/" + server + ".socket", "PW_POLL": "1"},
                                         stdout=output, stderr=subprocess.STDOUT)
                children.append(child)
                deadline = time.monotonic() + 3
                while child.poll() is None and time.monotonic() < deadline:
                    output.seek(0)
                    if b"ARMED codex" in output.read():
                        break
                    time.sleep(0.05)
                output.seek(0)
                self.assertIn(b"ARMED codex", output.read())
                self.assertIsNone(child.poll())
        finally:
            for child in children:
                if child.poll() is None:
                    child.terminate()
                child.wait(timeout=4)
            for output in outputs:
                output.close()
        self.assertFalse(list(self.directory.glob("pane-watch-locks/*/pid")))

    def test_watcher_replacement_loses_coverage(self):
        self.watcher_stub()
        code, output = self.run_tool("pane-watch/pane-watch.sh", "--pane", "%13", "--ui", "codex", "--ack-current",
                                     extra={"WATCH_TEST_REPLACE": "1", "PW_POLL": "0"}, timeout=2)
        self.assertEqual(code, 2, output)
        self.assertIn("identity changed", output)

    def test_relays_reject_disabled_timeouts(self):
        stub = self.executable("tmux-timeout", "exit 124")
        for relay in ("cc-msg.sh", "codex-send", "codex-send-to"):
            for setting in ("TMUX_TIMEOUT_SECONDS", "TMUX_TIMEOUT_KILL_AFTER"):
                with self.subTest(relay=relay, setting=setting):
                    args = ("lab-codex", "payload") if relay == "codex-send-to" else ("payload",)
                    code, output = self.run_tool(relay, *args, extra={"TMUX": "/tmp/ccmsg-lab-private-12345,1,0", "TMUX_BIN": str(stub),
                        "CC_MSG_SESSION": "lab-test", "CC_MSG_WINDOW": "lab-claude", "CODEX_SEND_SESSION": "lab-test", setting: "0"})
                    self.assertEqual(code, 1, output)
                    self.assertIn("positive", output)

    def test_relay_cleanup_does_not_retain_payload(self):
        retained = self.directory / "retained"
        self.executable("trash", 'mkdir -p "$RETAINED_ROOT"; [ ! -e "$1" ] || mv "$1" "$RETAINED_ROOT/"')
        script = '''fail() { exit 1; }
release_relay_lock() { :; }
request() { :; }
relay_script_dir="$TEST_TOOL_ROOT"
TMUX_TIMEOUT_SECONDS=1
TMUX_TIMEOUT_KILL_AFTER=1
source "$relay_script_dir/relay-delivery.sh"
relay_payload_dir="$(mktemp -d "$TMPDIR/relay-payload.XXXXXX")"
relay_payload_file="$relay_payload_dir/payload"
printf '%s' 'scratch-payload-residue-marker' > "$relay_payload_file"
printf '%s' 'scratch-payload-residue-marker' > "$relay_payload_dir/chunk-000000"
relay_cleanup
'''
        result = subprocess.run(["bash", "-c", script], env={**self.env, "TEST_TOOL_ROOT": str(ROOT / "tools"), "RETAINED_ROOT": str(retained)},
                                capture_output=True, text=True, timeout=3)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(b"scratch-payload-residue-marker" in path.read_bytes() for path in self.directory.rglob("*") if path.is_file()))

    def test_relay_cleanup_preserves_replaced_lock(self):
        self.executable("trash", 'rm -f "$1"')
        for relay in ("cc-msg.sh", "codex-send", "codex-send-to"):
            with self.subTest(relay=relay):
                lock = self.directory / "replaced-lock"
                lock.write_text("999999\n")
                source = (ROOT / "tools" / relay).read_text()
                start = source.index("release_relay_lock() {")
                function = source[start:source.index("\n}", start) + 2]
                result = subprocess.run(["bash", "-c", function + '\nrelay_lock="$LOCK_FILE"\nrelease_relay_lock'],
                                        env={**self.env, "LOCK_FILE": str(lock)}, capture_output=True, text=True, timeout=2)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(lock.exists())

    def test_input_guard_colon_color_preserves_intensity_reset(self):
        capture = "› \x1b[2mplaceholder\x1b[38:2::99:99:99;22mtyped\n\x1b[49m  Fast off · test · Context 0% used\n"
        result = subprocess.run([str(ROOT / "tools/relay-input-guard"), "›", "2", "0"],
                                input=capture, capture_output=True, text=True, timeout=2)
        self.assertEqual(result.returncode, 1, result.stderr)

    def test_guards_reject_unstructured_styled_boundaries(self):
        payload = self.directory / "payload"
        payload.write_text("relay payload")
        for footer in ("\x1b[49m  hidden draft", "\x1b[38;5;215m  Fast unknown · Draft Context", "\x1b[49m  Fast off"):
            with self.subTest(footer=footer):
                result = subprocess.run([str(ROOT / "tools/relay-input-guard"), "›", "2", "0"],
                                        input="› \n" + footer + "\n", capture_output=True, text=True, timeout=2)
                self.assertEqual(result.returncode, 1, result.stderr)
                result = subprocess.run([str(ROOT / "tools/relay-payload-guard"), "compare", "›", "15", "0", str(payload), "80"],
                                        input="› relay payload\n" + footer + "\n", capture_output=True, text=True, timeout=2)
                self.assertEqual(result.returncode, 1, result.stderr)

    def test_input_guard_divider_in_draft(self):
        capture = "❯\u00a0\n" + "─" * 30 + "\n" + "─" * 80 + "\n"
        result = subprocess.run([str(ROOT / "tools/relay-input-guard"), "❯", "2", "0"],
                                input=capture, capture_output=True, text=True, timeout=2)
        self.assertEqual(result.returncode, 1, result.stderr)

    def test_rescue_symlink_escape(self):
        outside = self.socket("outside.sock")
        lab = self.directory / "lab"
        lab.mkdir()
        alias = lab / "alias.sock"
        alias.symlink_to(outside)
        code, output = self.run_tool("tmux-loop-rescue", "--verify", extra={
            "TMUX_LOOP_RESCUE_SOCKET": str(alias), "TMUX_LOOP_RESCUE_LAB_ROOT": str(lab),
            "TMUX_LOOP_RESCUE_LAB": "1", "TMUX_LOOP_RESCUE_PID": "1", "TMUX_LOOP_RESCUE_COUNT": "1",
            "TMUX_LOOP_RESCUE_TMUX_BIN": str(self.directory / "missing"),
        })
        self.assertEqual(code, 1, output)
        self.assertIn("outside declared lab root", output)

    def test_rescue_parent_traversal(self):
        outside = self.socket("outside.sock")
        lab = self.directory / "lab"
        lab.mkdir()
        code, output = self.run_tool("tmux-loop-rescue", "--verify", extra={
            "TMUX_LOOP_RESCUE_SOCKET": str(lab) + "/../" + outside.name, "TMUX_LOOP_RESCUE_LAB_ROOT": str(lab),
            "TMUX_LOOP_RESCUE_LAB": "1", "TMUX_LOOP_RESCUE_PID": "1", "TMUX_LOOP_RESCUE_COUNT": "1",
            "TMUX_LOOP_RESCUE_TMUX_BIN": str(self.directory / "missing"),
        })
        self.assertEqual(code, 1, output)
        self.assertIn("outside declared lab root", output)


    def rescue_env(self, quoted=False):
        sock = self.socket("rescue.sock")
        executable = self.executable("rescue-executable", "exit 0")
        self.executable("lsof", '''case "$*" in
 *'-d txt'*) printf 'n%s\\n' "$STRESS_RESCUE_EXE" ;;
 *) printf 'tmux %s\\n' "$STRESS_RESCUE_PID" ;;
esac''')
        self.executable("dwarfdump", "echo 'UUID: TEST-UUID'")
        self.executable("sample", "printf '%s\\n' window_copy_command window_copy_cursor_down 'window_copy_cmd_cursor_down + 36 [0x1000]'")
        self.executable("llvm-objdump", "printf '%s\\n' '_window_copy_cmd_cursor_down:' '94 06 00 71 subs w20, w20, #0x1'")
        self.executable("tmux", "echo '%13|1|node'")
        self.executable("lldb", '''python3 - "$@" <<'PY'
import ast, pathlib, sys
command = pathlib.Path(sys.argv[sys.argv.index('-s') + 1]).read_text()
if 'process continue' in command:
    for line in command.splitlines():
        if line.startswith('script '):
            ast.parse(line[7:])
    print('TMUX_LOOP_FINAL=REFUSED:offline-test')
else:
    print('window_copy_cmd_cursor_down')
    print('subs w20, w20, #0x1')
    print('TMUX_LOOP_X20=0x20')
print('Process 123 detached')
PY''')
        return {"TMUX_LOOP_RESCUE_SOCKET": str(sock), "TMUX_LOOP_RESCUE_LAB_ROOT": str(self.directory),
                "TMUX_LOOP_RESCUE_LAB": "1", "TMUX_LOOP_RESCUE_PID": str(os.getpid()), "TMUX_LOOP_RESCUE_COUNT": "32",
                "TMUX_LOOP_RESCUE_EXPECTED_EXE": str(executable),
                "TMUX_LOOP_RESCUE_EXPECTED_SHA256": hashlib.sha256(executable.read_bytes()).hexdigest(),
                "TMUX_LOOP_RESCUE_EXPECTED_UUID": "TEST-UUID", "STRESS_RESCUE_EXE": str(executable),
                "STRESS_RESCUE_PID": str(os.getpid()),
                "TMUX_LOOP_RESCUE_EVIDENCE_ROOT": str(self.directory / ("evidence'quoted" if quoted else "evidence"))}



    def capture_env(self, status):
        path = self.socket("capture.sock")
        log = self.directory / "tmux.log"
        tmux = self.executable("tmux-stub", 'printf "%s\\n" "$*" >> "$STRESS_TMUX_LOG"\nexit ' + str(status))
        unavailable = str(self.directory / "unavailable")
        return {"TMUX_FREEZE_CAPTURE_SOCKET": str(path), "TMUX_FREEZE_CAPTURE_OUTPUT_ROOT": str(self.directory / "evidence"),
                "TMUX_FREEZE_CAPTURE_TMUX_BIN": str(tmux), "TMUX_FREEZE_CAPTURE_LSOF_BIN": unavailable,
                "TMUX_FREEZE_CAPTURE_SAMPLE_BIN": unavailable, "STRESS_TMUX_LOG": str(log)}, log




    def test_rescue_missing_settings(self):
        code, output = self.run_tool("tmux-loop-rescue", "--verify", extra={"TMUX_LOOP_RESCUE_SOCKET": ""})
        self.assertEqual(code, 1, output)
        self.assertIn("SOCKET is required", output)




if __name__ == "__main__":
    unittest.main(verbosity=2)
