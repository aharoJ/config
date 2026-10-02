#!/usr/bin/env python3
# path: ~/.config/tmux/tests/tool-stress-regression.py
# description: Attack watcher invocation, incident boundaries, and status fallbacks without live tmux.
# patched: model Claude's verified idle footer in cleanup stress cases
# date: 2026-10-02T04:00:00Z
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
        self.executable("trash", 'rm -rf -- "$@"')
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

    def live_manifest(self, rows=None):
        rows = rows or [
            "fresh-empty\tfresh\t0\t0.159.3\tOpenAI Codex (v0.159.3)",
            "post-subagent-empty\tpost\t0\t0.159.3\tMain [default]",
            "working-empty\tworking\t0\t0.159.3\tWorking",
            "single-line-draft\tsingle\t1\t0.159.3\tsingle draft",
            "multiline-draft\tmultiline\t1\t0.159.3\tsecond draft",
            "home-cursor-draft\thome\t1\t0.159.3\thome draft",
        ]
        manifest = self.directory / "live-corpus.tsv"
        manifest.write_text("\n".join(rows) + "\n")
        return manifest

    def live_capture_stub(self):
        version = self.executable("codex-version", "printf 'codex-cli 0.159.3\\n'")
        source = (
            r'command=; target=; previous=; '
            r'for argument in "$@"; do [ "$previous" = -t ] && target=$argument; case "$argument" in display-message|capture-pane) command=$argument ;; esac; previous=$argument; done; '
            r'case "$command:$target" in '
            r'display-message:fresh) printf "%%13:4242:codex:0:2:1:167:51\\n" ;; '
            r'display-message:post) printf "%%13:4242:codex:0:2:0:167:51\\n" ;; '
            r'display-message:working) printf "%%13:4242:codex:0:2:1:167:51\\n" ;; '
            r'display-message:single) printf "%%13:4242:codex:0:14:0:167:51\\n" ;; '
            r'display-message:multiline) printf "%%13:4242:codex:0:14:1:167:51\\n" ;; '
            r'display-message:home) if [ "${LIVE_CAPTURE_HOME_END:-0}" = 1 ]; then printf "%%13:4242:codex:0:14:0:167:51\\n"; else printf "%%13:4242:codex:0:2:0:167:51\\n"; fi ;; '
            r'capture-pane:fresh) count=0; [ ! -f "$TMPDIR/live-count" ] || count=$(cat "$TMPDIR/live-count"); count=$((count + 1)); printf "%s\\n" "$count" > "$TMPDIR/live-count"; if [ "${LIVE_CAPTURE_UNSTABLE:-0}" = 1 ] && [ "$count" -gt 1 ]; then printf "%b\\n" "\\e[1mOpenAI Codex (v0.159.3)\\e[0m\\n\\e[1m›\\e[0m \\e[2mAsk Codex to do anything\\e[0m\\n  NEW USER DRAFT DURING CAPTURE\\n\\n\\e[49m  \\e[38;2;200;169;238mFast off\\e[39m · \\e[38;2;246;226;183mGPT-6.1-Sol low\\e[39m · \\e[38;2;171;223;167m~/lab\\e[39m · \\e[38;2;242;181;144mContext 0% used\\e[39m"; else printf "%b\\n" "\\e[1mOpenAI Codex (v0.159.3)\\e[0m\\n\\e[1m›\\e[0m \\e[2mAsk Codex to do anything\\e[0m\\n\\n\\e[49m  \\e[38;2;200;169;238mFast off\\e[39m · \\e[38;2;246;226;183mGPT-6.1-Sol low\\e[39m · \\e[38;2;171;223;167m~/lab\\e[39m · \\e[38;2;242;181;144mContext 0% used\\e[39m"; fi ;; '
            r'capture-pane:post) printf "%b\\n" "\\e[1m›\\e[0m \\e[2mAsk Codex to do anything\\e[0m\\n\\n\\e[49m  \\e[38;2;200;169;238mFast off\\e[39m · \\e[38;2;246;226;183mGPT-6.1-Sol low\\e[39m · \\e[38;2;171;223;167m~/lab\\e[39m · \\e[38;2;242;181;144mContext 1% used\\e[39m · Main [default]" ;; '
            r'capture-pane:working) printf "%b\\n" "Working (1s · esc to interrupt)\\n\\e[1m›\\e[0m \\e[2mAsk Codex to do anything\\e[0m\\n\\n\\e[49m  \\e[38;2;200;169;238mFast off\\e[39m · \\e[38;2;246;226;183mGPT-6.1-Sol low\\e[39m · \\e[38;2;171;223;167m~/lab\\e[39m · \\e[38;2;242;181;144mContext 1% used\\e[39m" ;; '
            r'capture-pane:single) printf "%b\\n" "\\e[1m›\\e[0m single draft\\n\\n\\e[49m  \\e[38;2;200;169;238mFast off\\e[39m · \\e[38;2;246;226;183mGPT-6.1-Sol low\\e[39m · \\e[38;2;171;223;167m~/lab\\e[39m · \\e[38;2;242;181;144mContext 1% used\\e[39m" ;; '
            r'capture-pane:multiline) printf "%b\\n" "\\e[1m›\\e[0m \\n  second draft\\n\\n\\e[49m  \\e[38;2;200;169;238mFast off\\e[39m · \\e[38;2;246;226;183mGPT-6.1-Sol low\\e[39m · \\e[38;2;171;223;167m~/lab\\e[39m · \\e[38;2;242;181;144mContext 1% used\\e[39m" ;; '
            r'capture-pane:home) printf "%b\\n" "\\e[1m›\\e[0m home draft\\n\\n\\e[49m  \\e[38;2;200;169;238mFast off\\e[39m · \\e[38;2;246;226;183mGPT-6.1-Sol low\\e[39m · \\e[38;2;171;223;167m~/lab\\e[39m · \\e[38;2;242;181;144mContext 1% used\\e[39m" ;; '
            r'*) exit 1 ;; esac'
        )
        source = source.replace("\\\\", "\\")
        self.executable("tmux", source)
        return version

    def test_live_capture_accepts_stable_complete_corpus(self):
        manifest = self.live_manifest()
        version = self.live_capture_stub()
        result = subprocess.run(["bash", str(ROOT / "tests/relay-live-capture-regression.sh"), "--manifest", str(manifest)],
                                env={**self.env, "TMUX": "/private/tmp/tmux-501/ccmsg-lab-private-99999,1,0",
                                     "CODEX_VERSION_BIN": str(version)}, capture_output=True, text=True, timeout=4)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("6 stable current Codex states, PASS", result.stdout)

    def test_live_capture_rejects_incomplete_manifest_before_tmux(self):
        marker = self.directory / "called"
        manifest = self.live_manifest(["fresh-empty\tfresh\t0\t0.159.3\tOpenAI Codex (v0.159.3)"])
        self.executable("tmux", 'touch "$DEFAULT_CALL_MARKER"; exit 0')
        result = subprocess.run(["bash", str(ROOT / "tests/relay-live-capture-regression.sh"), "--manifest", str(manifest)],
                                env={**self.env, "TMUX": "/private/tmp/tmux-501/ccmsg-lab-private-99999,1,0",
                                     "DEFAULT_CALL_MARKER": str(marker)}, capture_output=True, text=True, timeout=2)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("missing required", result.stderr)
        self.assertFalse(marker.exists())

    def test_live_capture_rejects_changed_styled_snapshot(self):
        manifest = self.live_manifest()
        version = self.live_capture_stub()
        result = subprocess.run(["bash", str(ROOT / "tests/relay-live-capture-regression.sh"), "--manifest", str(manifest)],
                                env={**self.env, "TMUX": "/private/tmp/tmux-501/ccmsg-lab-private-99999,1,0",
                                     "CODEX_VERSION_BIN": str(version), "LIVE_CAPTURE_UNSTABLE": "1"},
                                capture_output=True, text=True, timeout=4)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("styled screen changed", result.stderr)

    def test_live_capture_rejects_cursor_only_classifier(self):
        manifest = self.live_manifest()
        version = self.live_capture_stub()
        clone = self.directory / "live-gate-clone"
        (clone / "tests").mkdir(parents=True)
        (clone / "tools").mkdir()
        gate = clone / "tests" / "relay-live-capture-regression.sh"
        shutil.copyfile(ROOT / "tests" / "relay-live-capture-regression.sh", gate)
        guard = clone / "tools" / "relay-input-guard"
        guard.write_text('#!/usr/bin/env bash\n[ "$2" = 2 ] && exit 0\nexit 1\n')
        guard.chmod(0o755)
        result = subprocess.run(["bash", str(gate), "--manifest", str(manifest)],
                                env={**self.env, "TMUX": "/private/tmp/tmux-501/ccmsg-lab-private-99999,1,0",
                                     "CODEX_VERSION_BIN": str(version)}, capture_output=True, text=True, timeout=4)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("home-cursor-draft guard returned 0, expected 1", result.stderr)

    def test_live_capture_rejects_home_case_at_end_of_draft(self):
        manifest = self.live_manifest()
        version = self.live_capture_stub()
        result = subprocess.run(["bash", str(ROOT / "tests/relay-live-capture-regression.sh"), "--manifest", str(manifest)],
                                env={**self.env, "TMUX": "/private/tmp/tmux-501/ccmsg-lab-private-99999,1,0",
                                     "CODEX_VERSION_BIN": str(version), "LIVE_CAPTURE_HOME_END": "1"},
                                capture_output=True, text=True, timeout=4)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("home-cursor-draft must remain at the prompt column", result.stderr)

    def test_live_capture_rejects_missing_required_state_marker(self):
        rows = [
            "fresh-empty\tfresh\t0\t0.159.3\tOpenAI Codex (v0.159.3)",
            "post-subagent-empty\tpost\t0\t0.159.3\tMain [default]",
            "working-empty\tworking\t0\t0.159.3\tWorking",
            "single-line-draft\tsingle\t1\t0.159.3\tmissing draft marker",
            "multiline-draft\tmultiline\t1\t0.159.3\tsecond draft",
            "home-cursor-draft\thome\t1\t0.159.3\thome draft",
        ]
        manifest = self.live_manifest(rows)
        version = self.live_capture_stub()
        result = subprocess.run(["bash", str(ROOT / "tests/relay-live-capture-regression.sh"), "--manifest", str(manifest)],
                                env={**self.env, "TMUX": "/private/tmp/tmux-501/ccmsg-lab-private-99999,1,0",
                                     "CODEX_VERSION_BIN": str(version)}, capture_output=True, text=True, timeout=4)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("single-line-draft lacks required visible marker", result.stderr)

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

    def test_relay_cleanup_retains_payload_in_trash(self):
        self.executable("trash", 'mkdir -p "$RETAINED_ROOT"; [ ! -e "$1" ] || mv "$1" "$RETAINED_ROOT/"')
        for relay in ("cc-msg.sh", "codex-send", "codex-send-to"):
            with self.subTest(relay=relay):
                retained = self.directory / ("retained-" + relay)
                source = (ROOT / "tools" / relay).read_text()
                start = source.index("release_relay_lock() {")
                function = source[start:source.index("\n}", start) + 2]
                script = function + '''
fail() { exit 1; }
request() { :; }
relay_script_dir="$TEST_TOOL_ROOT"
TMUX_TIMEOUT_SECONDS=1
TMUX_TIMEOUT_KILL_AFTER=1
source "$relay_script_dir/relay-delivery.sh"
relay_payload_dir="$(mktemp -d "$TMPDIR/relay-payload.XXXXXX")"
relay_payload_file="$relay_payload_dir/payload"
printf '%s' 'scratch-payload-residue-marker' > "$relay_payload_file"
printf '%s' 'scratch-payload-residue-marker' > "$relay_payload_dir/chunk-000000"
list_file="$(mktemp "$TMPDIR/relay-list.XXXXXX")"
printf '%s' 'list-residue-marker' > "$list_file"
relay_lock="$(mktemp "$TMPDIR/relay-lock.XXXXXX")"
printf '%s\n' "$$" > "$relay_lock"
relay_cleanup
'''
                result = subprocess.run(["bash", "-c", script], env={**self.env, "TEST_TOOL_ROOT": str(ROOT / "tools"), "RETAINED_ROOT": str(retained)},
                                        capture_output=True, text=True, timeout=3)
                self.assertEqual(result.returncode, 0, result.stderr)
                payloads = [path for path in retained.rglob("*") if path.is_file() and path.read_bytes() == b"scratch-payload-residue-marker"]
                self.assertEqual(len(payloads), 2)
                self.assertEqual(len(list(retained.glob("relay-list.*"))), 1)
                self.assertEqual(len(list(retained.glob("relay-lock.*"))), 1)
                self.assertFalse(list(self.directory.glob("relay-payload.*")))
                self.assertFalse(list(self.directory.glob("relay-list.*")))
                self.assertFalse(list(self.directory.glob("relay-lock.*")))

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

    def test_public_relays_report_failed_trash(self):
        self.executable("trash", "exit 42")
        self.executable("ps", "exit 1")
        locker = self.executable("shlock", 'printf "%s\\n" "$4" > "$2"')
        timer = self.executable("timeout", 'shift 3; exec "$@"')
        proxy = self.executable("tmux", '''if [ "${TRASH_TEST_SIGNAL:-0}" = 1 ] && [ "$1" = load-buffer ]; then
 kill -TERM "$PPID"
 exit 0
fi
exec "$TRASH_TEST_STUB" "$@"''')
        for relay in ("cc-msg.sh", "codex-send", "codex-send-to"):
            for signal_stage in (False, True):
                with self.subTest(relay=relay, signal=signal_stage):
                    directory = self.directory / (relay + ("-signal" if signal_stage else "-delivered"))
                    directory.mkdir()
                    window = "claude" if relay == "cc-msg.sh" else "codex"
                    command = "2.1.286" if relay == "cc-msg.sh" else "node"
                    capture = "❯\u00a0\n" + "─" * 192 + "\n  Opus 5.5 | v2.1.287\n  ⏵⏵ bypass permissions on" if relay == "cc-msg.sh" else "› \x1b[2mAsk Codex to do anything\x1b[0m\n\x1b[49m  Fast off · test · Context 0% used"
                    env = {**self.env, "TMPDIR": str(directory), "TMUX": str(directory / "socket") + ",0,0",
                           "TMUX_BIN": str(proxy), "TIMEOUT_BIN": str(timer), "TMUX_RELAY_LOCK_BIN": str(locker),
                           "TMUX_RELAY_LOCK_ROOT": str(directory / "locks"), "TRASH_TEST_SIGNAL": str(int(signal_stage)),
                           "TRASH_TEST_STUB": str(ROOT / "tests/relay-tmux-stub.sh"),
                           "RELAY_TEST_CAPTURE": capture, "RELAY_TEST_LOG": str(directory / "tmux.log"),
                           "RELAY_TEST_PANES": f"%13 relaytest {window} {command} 100 0",
                           "CC_MSG_SESSION": "relaytest", "CC_MSG_WINDOW": window, "CODEX_SEND_SESSION": "relaytest"}
                    argv = [str(ROOT / "tools" / relay)]
                    if relay == "codex-send-to":
                        argv.append(window)
                    argv.append("failed-trash-payload-marker")
                    result = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=4)
                    self.assertEqual(result.returncode, 1 if signal_stage else 0, result.stderr)
                    if signal_stage:
                        self.assertIn("interrupted by SIGTERM", result.stderr)
                    else:
                        self.assertIn("complete composer verified", result.stdout)
                    for artifact in ("payload scratch", "list scratch", "owned lock"):
                        self.assertIn(artifact + " cleanup is unconfirmed", result.stderr)
                    payloads = list(directory.glob("relay-payload.*"))
                    self.assertEqual(len(payloads), 1)
                    self.assertIn("failed-trash-payload-marker", (payloads[0] / "payload").read_text())
                    self.assertTrue(list(payloads[0].glob("chunk-*")))
                    self.assertEqual((payloads[0] / "send-keys-Enter.tmux").exists(), not signal_stage)
                    self.assertTrue(list(directory.glob("*-list.*")))
                    self.assertEqual(len(list((directory / "locks").iterdir())), 1)

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

    def test_rescue_production_loop_overrides(self):
        for setting in ("FRAME", "FUNCTION", "PC_OFFSET", "INSTRUCTION_BYTES"):
            with self.subTest(setting=setting):
                code, output = self.run_tool("tmux-loop-rescue", "--production", "--verify", extra={
                    "TMUX_LOOP_RESCUE_SOCKET": "/private/tmp/tmux-501/default", "TMUX_LOOP_RESCUE_PID": "1",
                    "TMUX_LOOP_RESCUE_COUNT": "1", "TMUX_LOOP_RESCUE_PRODUCTION_ACK": "I-ACK-PRODUCTION-ATTACH",
                    "TMUX_LOOP_RESCUE_EVIDENCE_ROOT": str(self.directory),
                    "TMUX_LOOP_RESCUE_EXPECTED_" + setting: "unexpected",
                })
                self.assertEqual(code, 1, output)
                self.assertIn("production loop overrides are forbidden", output)

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

    def test_rescue_rejects_future_observation(self):
        extra = self.rescue_env()
        observe = {**extra}
        observe.pop("TMUX_LOOP_RESCUE_COUNT")
        code, output = self.run_tool("tmux-loop-rescue", "--observe", extra=observe, timeout=6)
        self.assertEqual(code, 0, output)
        observation = next((self.directory / "evidence").glob("*/observation.tsv"))
        values = dict(line.split("=", 1) for line in observation.read_text().splitlines())
        values["created_epoch"] = str(int(time.time()) + 3600)
        observation.write_text("".join(key + "=" + value + "\n" for key, value in values.items()))
        result = subprocess.run([str(ROOT / "tools/tmux-loop-rescue")],
                                env={**self.env, **extra, "TMUX_LOOP_RESCUE_OBSERVATION": str(observation),
                                     "TMUX_LOOP_RESCUE_OBSERVATION_NONCE": values["nonce"]},
                                input="decline\n", capture_output=True, text=True, timeout=6)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("OBSERVATION=FAIL", result.stderr)

    def test_rescue_quotes_evidence_path(self):
        extra = self.rescue_env(quoted=True)
        result = subprocess.run([str(ROOT / "tools/tmux-loop-rescue")], env={**self.env, **extra},
                                input=extra["TMUX_LOOP_RESCUE_PID"] + "\n", capture_output=True, text=True, timeout=6)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("offline-test", result.stderr)
        self.assertNotIn("completion was not established", result.stderr)

    def capture_env(self, status):
        path = self.socket("capture.sock")
        log = self.directory / "tmux.log"
        tmux = self.executable("tmux-stub", 'printf "%s\\n" "$*" >> "$STRESS_TMUX_LOG"\nexit ' + str(status))
        unavailable = str(self.directory / "unavailable")
        return {"TMUX_FREEZE_CAPTURE_SOCKET": str(path), "TMUX_FREEZE_CAPTURE_OUTPUT_ROOT": str(self.directory / "evidence"),
                "TMUX_FREEZE_CAPTURE_TMUX_BIN": str(tmux), "TMUX_FREEZE_CAPTURE_LSOF_BIN": unavailable,
                "TMUX_FREEZE_CAPTURE_SAMPLE_BIN": unavailable, "STRESS_TMUX_LOG": str(log)}, log

    def test_capture_stops_after_timeout(self):
        extra, log = self.capture_env(124)
        code, output = self.run_tool("tmux-freeze-capture.fish", extra=extra, timeout=8)
        self.assertEqual(code, 1, output)
        self.assertEqual(len(log.read_text().splitlines()), 1)
        self.assertIn("stopped", output.lower())

    def test_capture_private_permissions(self):
        extra, log = self.capture_env(0)
        code, output = self.run_tool("tmux-freeze-capture.fish", extra=extra, timeout=8, umask=0)
        self.assertEqual(code, 0, output)
        for path in (self.directory / "evidence").rglob("*"):
            self.assertEqual(path.stat().st_mode & 0o077, 0, str(path))

    def test_capture_invalid_timeout(self):
        for value in ("0", "11", "-1", "garbage", "1;touch nope"):
            code, output = self.run_tool("tmux-freeze-capture.fish", extra={"TMUX_FREEZE_CAPTURE_TMUX_TIMEOUT_SECONDS": value})
            self.assertEqual(code, 64, output)

    def test_rescue_missing_settings(self):
        code, output = self.run_tool("tmux-loop-rescue", "--verify", extra={"TMUX_LOOP_RESCUE_SOCKET": ""})
        self.assertEqual(code, 1, output)
        self.assertIn("SOCKET is required", output)

    def test_status_memory_fallback(self):
        self.executable("sysctl", 'case "$*" in *hw.ncpu*) echo 4 ;; *hw.memsize*) echo 8589934592 ;; esac')
        self.executable("ps", "printf '20\\n20\\n'")
        self.executable("memory_pressure", "exit 1")
        self.executable("vm_stat", "printf '%s\\n' 'Mach Virtual Memory Statistics: (page size of 16384 bytes)' 'Pages free: 10.' 'Pages speculative: 20.' 'Pages inactive: 30.' 'Pages active: 40.' 'Pages wired down: 65536.'")
        result = subprocess.run([str(ROOT / "scripts/gpt.sh")], env=self.env, capture_output=True, text=True, timeout=3)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "CPU 10% · RAM 1.0G/8.0G")

    def test_sender_rechecks_process_ancestry(self):
        self.executable("ps", '''count=0
[ ! -f "$TMPDIR/ps-count" ] || count=$(cat "$TMPDIR/ps-count")
count=$((count + 1)); echo "$count" > "$TMPDIR/ps-count"
if [ "$count" = 1 ]; then agent=codex; else agent=claude; fi
printf '9000 8800 /bin/bash\\n8800 1 /opt/bin/%s\\n' "$agent"''')
        panes = self.directory / "panes"
        panes.write_text("%13 lab-test lab-worker node 8800 0\n")
        result = subprocess.run([str(ROOT / "tools/relay-sender-label"), "9000", str(panes)], env=self.env,
                                capture_output=True, text=True, timeout=2)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
