#!/usr/bin/env python3
# path: ~/.config/tmux/tests/tmux-lab-regression.py
# description: Verify private tmux lab ownership, teardown, stale detection, and refusal paths.
# date: 2026-10-02
import json
import os
import pathlib
import signal
import socket
import importlib.machinery
import importlib.util
import subprocess
import sys
import time
import unittest
import uuid


ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/tmux-lab"
GUARD = ROOT / "tests/private-tmux-guard.py"
LAB = pathlib.Path.home() / "desk/lab"
LEDGER = LAB / "tmux-lab-ledger"
REAL = "/opt/homebrew/bin/tmux"


def record_for(pid):
    paths = sorted(LEDGER.glob(f"run-{pid}-*/record.json"))
    return json.loads(paths[-1].read_text()) if paths else None


def wait_record(pid, state="running"):
    for _ in range(100):
        record = record_for(pid)
        if record and record["state"] == state:
            return record
        time.sleep(0.05)
    raise AssertionError(f"missing {state} record for {pid}: {record_for(pid)}")


def independent_absence(record):
    pid = record["server_pid"]
    proc = subprocess.run(["ps", "-p", str(pid), "-o", "pid="], capture_output=True, text=True)
    sockets = subprocess.run(["lsof", "-nU"], capture_output=True, text=True)
    return not proc.stdout.strip() and record["socket_path"] not in sockets.stdout


class TmuxLabTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output = LAB / ("tmux-lab-tests-" + uuid.uuid4().hex[:8])
        cls.output.mkdir()

    def test_unregistered_private_server_is_reported(self):
        name = "ccmsg-lab-private-outside-" + uuid.uuid4().hex[:10]
        started = subprocess.run([REAL, "-L", name, "-f", "/dev/null", "new-session", "-d", "-s", "lab-census", "exec sleep 60"], capture_output=True, text=True)
        self.assertEqual(started.returncode, 0, started.stderr)
        try:
            rows = [json.loads(line) for line in subprocess.run([str(TOOL), "ls"], capture_output=True, text=True, check=True).stdout.splitlines()]
            found = [row for row in rows if row.get("socket") == name]
            self.assertEqual(len(found), 1, found)
            self.assertEqual(found[0]["state"], "unregistered")
            self.assertEqual(found[0]["socket_observation"], "live")
            self.assertTrue(found[0]["listener_pids"])
        finally:
            subprocess.run([REAL, "-L", name, "-f", "/dev/null", "kill-server"], capture_output=True, check=True)
        census = subprocess.run(["lsof", "-nU"], capture_output=True, text=True, check=True)
        self.assertNotIn("/tmux-" + str(os.getuid()) + "/" + name, census.stdout)

    def test_reused_registered_socket_is_unregistered(self):
        owner = subprocess.Popen([str(TOOL), "run", "--", "/usr/bin/true"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        _, err = owner.communicate(timeout=12)
        self.assertEqual(owner.returncode, 0, err)
        old = record_for(owner.pid)
        self.assertTrue(independent_absence(old))
        name = old["socket"]
        started = subprocess.run([REAL, "-L", name, "-f", "/dev/null", "new-session", "-d", "-s", "lab-reused", "exec sleep 60"], capture_output=True, text=True)
        self.assertEqual(started.returncode, 0, started.stderr)
        try:
            rows = [json.loads(line) for line in subprocess.run([str(TOOL), "ls"], capture_output=True, text=True, check=True).stdout.splitlines()]
            matching = [row for row in rows if row.get("socket") == name]
            self.assertEqual(len(matching), 2, matching)
            self.assertEqual(len([row for row in matching if row.get("state") == "unregistered" and row.get("socket_observation") == "live"]), 1)
        finally:
            subprocess.run([REAL, "-L", name, "-f", "/dev/null", "kill-server"], capture_output=True, check=True)

    def test_custom_socket_path_with_spaces_is_reported(self):
        directory = self.output / 'space d'
        directory.mkdir()
        path = directory / ('ccmsg-lab-private-path-' + str(os.getpid()))
        started = subprocess.run([REAL,'-S',str(path),'-f','/dev/null','new-session','-d','-s','lab-path','exec sleep 60'],capture_output=True,text=True)
        self.assertEqual(started.returncode,0,started.stderr)
        try:
            rows = [json.loads(line) for line in subprocess.run([str(TOOL),'ls'],capture_output=True,text=True,check=True).stdout.splitlines()]
            found = [row for row in rows if row.get('socket_path') == os.path.realpath(path)]
            self.assertEqual(len(found),1,found)
            self.assertEqual(found[0]['state'],'unregistered')
            self.assertEqual(found[0]['socket_observation'],'live')
            self.assertTrue(found[0]['listener_pids'])
        finally:
            subprocess.run([REAL,'-S',str(path),'-f','/dev/null','kill-server'],capture_output=True,check=True)

    def test_detached_exec_and_fork_escapes_are_detected_without_adopting_decoy(self):
        decoy = subprocess.Popen(['/bin/sleep', '120'], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        baseline = {int(line) for line in subprocess.run(['ps', '-axo', 'pid='], capture_output=True, text=True, check=True).stdout.splitlines() if line.strip().isdigit()}
        worker = self.output / 'detach-worker.py'
        marker = self.output / 'detach-pids.json'
        worker.write_text('''import os,sys,subprocess,time,json,signal
exec_child = subprocess.Popen(['/bin/sleep','120'], start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
fork_child = os.fork()
if fork_child == 0:
    os.setsid()
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    time.sleep(120)
    os._exit(0)
open(sys.argv[1], 'w').write(json.dumps([exec_child.pid, fork_child]))
''')
        driver = self.output / 'detach-driver.py'
        driver.write_text('''import os,sys,subprocess,time,pathlib
subprocess.run([os.environ['TMUX_BIN'],'-L',os.environ['TMUX_LAB_SOCKET'],'new-window','-d','-n','escaped',sys.argv[1]],check=True)
for _ in range(100):
    if pathlib.Path(sys.argv[2]).exists():
        time.sleep(0.3)
        sys.exit(42)
    time.sleep(0.05)
sys.exit(23)
''')
        command = str(sys.executable) + ' ' + str(worker) + ' ' + str(marker)
        owner = subprocess.Popen([str(TOOL), 'run', '--', sys.executable, str(driver), command, str(marker)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            out, err = owner.communicate(timeout=15)
            self.assertEqual(owner.returncode, 42, err + out)
            pids = json.loads(marker.read_text())
            record = record_for(owner.pid)
            candidates = {row['pid'] for row in record['escape_candidates']}
            self.assertTrue(set(pids) <= candidates, record)
            self.assertFalse(candidates & baseline, record)
            self.assertEqual(record['state'], 'closed')
            for pid in pids:
                self.assertFalse(subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip(), str(pid))
            self.assertIsNone(decoy.poll())
            self.assertTrue(independent_absence(record))
            print('detached exec/fork escapes detected and removed; unrelated baseline and decoy excluded; exit 42 preserved')
        finally:
            if owner.poll() is None:
                owner.terminate(); owner.wait(timeout=10)
            decoy.terminate(); decoy.wait(timeout=5)

    def test_refused_escape_signals_are_loud_and_visible_until_gone(self):
        marker = self.output / 'report-only.pid'
        driver = self.output / 'report-only-driver.py'
        driver.write_text("import subprocess,sys\np=subprocess.Popen(['/bin/sleep','120'],start_new_session=True,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\nopen(sys.argv[1],'w').write(str(p.pid))\nsys.exit(42)\n")
        harness = self.output / 'report-only-harness.py'
        harness.write_text('''import ctypes,os,sys,importlib.machinery,importlib.util
loader=importlib.machinery.SourceFileLoader('tmux_lab',sys.argv[1])
spec=importlib.util.spec_from_loader('tmux_lab',loader)
module=importlib.util.module_from_spec(spec);loader.exec_module(module)
if module.responsible_pid(os.getpid()) != os.getpid():
    lib=module.SYSTEM;attr=ctypes.c_void_p();assert lib.posix_spawnattr_init(ctypes.byref(attr)) == 0
    assert lib.responsibility_spawnattrs_setdisclaim(ctypes.byref(attr),True) == 0
    assert lib.posix_spawnattr_setflags(ctypes.byref(attr),0x0040) == 0
    args=[os.fsencode(sys.executable),*map(os.fsencode,sys.argv)]
    argv=(ctypes.c_char_p*(len(args)+1))(*args,None)
    values=[os.fsencode(k+'='+v) for k,v in os.environ.items()]
    envp=(ctypes.c_char_p*(len(values)+1))(*values,None)
    pid=ctypes.c_int();raise RuntimeError(lib.posix_spawn(ctypes.byref(pid),args[0],None,ctypes.byref(attr),argv,envp))
os.environ['TMUX_LAB_RESPONSIBLE_PID']=str(os.getpid())
module.signal_scoped_process=lambda record,row,signum: False
sys.exit(module.run_command(['--',sys.executable,sys.argv[2],sys.argv[3]]))
''')
        owner = subprocess.Popen([sys.executable,str(harness),str(TOOL),str(driver),str(marker)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        pid = None
        try:
            out, err = owner.communicate(timeout=15)
            self.assertEqual(owner.returncode, 42, err + out)
            pid = int(marker.read_text())
            record = record_for(owner.pid)
            self.assertEqual(record['state'], 'closed-with-escapes', record)
            self.assertIn('ESCAPED PROCESS pid=' + str(pid), err)
            self.assertIn('/bin/sleep 120', err)
            report = subprocess.run([str(TOOL),'ls'], capture_output=True, text=True, check=True)
            row = next(json.loads(line) for line in report.stdout.splitlines() if json.loads(line).get('record') == str(next(LEDGER.glob('run-' + str(owner.pid) + '-*/record.json'))))
            self.assertEqual(row['escape_observation'], 'live')
            self.assertEqual([item['pid'] for item in row['escaped_processes']], [pid])
            os.kill(pid,signal.SIGTERM)
            for _ in range(50):
                if not subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip(): break
                time.sleep(0.05)
            report = subprocess.run([str(TOOL),'ls'], capture_output=True, text=True, check=True)
            row = next(json.loads(line) for line in report.stdout.splitlines() if json.loads(line).get('record') == row['record'])
            self.assertEqual(row['escape_observation'], 'gone')
            print('signal refusal: closed-with-escapes, stderr PID/command, ls live then gone, child exit 42')
        finally:
            if owner.poll() is None: owner.terminate(); owner.wait(timeout=10)
            if pid:
                try: os.kill(pid,signal.SIGTERM)
                except ProcessLookupError: pass

    def test_escape_signal_refuses_wrong_unique_identity_and_wrong_attribution(self):
        loader = importlib.machinery.SourceFileLoader('tmux_lab_signal', str(TOOL))
        spec = importlib.util.spec_from_loader('tmux_lab_signal', loader)
        module = importlib.util.module_from_spec(spec); loader.exec_module(module)
        decoy = subprocess.Popen(['/bin/sleep','120'], start_new_session=True)
        try:
            current = module.kernel_process(decoy.pid)
            root = module.responsible_pid(decoy.pid)
            record = {'owner_pid':root,'owner_unique_id':module.unique_identity(root),'uid':os.getuid(),'created':time.time()-1}
            row = {'pid':decoy.pid,**current,'unique_id':module.unique_identity(decoy.pid)+1}
            self.assertFalse(module.signal_scoped_process(record,row,signal.SIGTERM))
            self.assertIsNone(decoy.poll())
            record.update(owner_pid=os.getpid(),owner_unique_id=module.unique_identity(os.getpid()))
            row['unique_id'] = module.unique_identity(decoy.pid)
            self.assertFalse(module.signal_scoped_process(record,row,signal.SIGTERM))
            self.assertIsNone(decoy.poll())
        finally:
            decoy.terminate(); decoy.wait(timeout=5)

    def test_guard_refuses_default_context(self):
        audit = self.output / "guard-audit.jsonl"
        env = os.environ.copy()
        env.update({"STRESS_PRIVATE_SOCKET": "ccmsg-lab-private-1", "STRESS_REAL_TMUX": REAL,
                    "STRESS_TMUX_AUDIT_LOG": str(audit), "TMUX": ""})
        result = subprocess.run([sys.executable, str(GUARD), "ls"], env=env)
        self.assertEqual(result.returncode, 97)
        self.assertFalse(audit.exists())

    def test_success_failure_and_proxy_refusals(self):
        script = self.output / "proxy-probe.sh"
        script.write_text('''#!/bin/sh
set -u
"$TMUX_BIN" -L "$TMUX_LAB_SOCKET" -f /dev/null new-session -d -s lab-probe -n check 'exec sleep 60'
"$TMUX_BIN" -L "$TMUX_LAB_SOCKET" -f /dev/null list-sessions -F '#{session_name}'
server_pid=$("$TMUX_BIN" -L "$TMUX_LAB_SOCKET" display-message -p -t lab-probe '#{pid}')
ps -p "$server_pid" -o command=
for probe in missing default wrong_config custom_socket attach wrong_session; do
  case "$probe" in
    missing) "$TMUX_BIN" list-sessions ;;
    default) "$TMUX_BIN" -L default -f /dev/null list-sessions ;;
    wrong_config) "$TMUX_BIN" -L "$TMUX_LAB_SOCKET" -f /not-dev-null list-sessions ;;
    custom_socket) "$TMUX_BIN" -S /private/tmp/other list-sessions ;;
    attach) "$TMUX_BIN" -L "$TMUX_LAB_SOCKET" -f /dev/null attach-session ;;
    wrong_session) "$TMUX_BIN" -L "$TMUX_LAB_SOCKET" -f /dev/null new-session -d -s ordinary -n no 'exec sleep 60' ;;
  esac
  code=$?
  [ "$code" -eq 97 ] || exit 23
done
''')
        script.chmod(0o700)
        success = subprocess.run([str(TOOL), "run", "--", str(script)], capture_output=True, text=True)
        self.assertEqual(success.returncode, 0, success.stderr + success.stdout)
        self.assertIn("lab-probe", success.stdout)
        self.assertIn("-f /dev/null", success.stdout)
        record = json.loads(sorted(LEDGER.glob("run-*/record.json"), key=lambda p: p.stat().st_mtime)[-1].read_text())
        self.assertEqual(record["state"], "closed")
        self.assertTrue(independent_absence(record))
        failure = subprocess.run([str(TOOL), "run", "--", "/bin/sh", "-c", "exit 42"], capture_output=True, text=True)
        self.assertEqual(failure.returncode, 42, failure.stderr)
        self.assertTrue(independent_absence(json.loads(sorted(LEDGER.glob("run-*/record.json"), key=lambda p: p.stat().st_mtime)[-1].read_text())))

    def test_scripted_multistep_probe_closes_after_last_step(self):
        script = self.output / "multistep.sh"
        script.write_text('''#!/bin/sh
set -eu
"$TMUX_BIN" -L "$TMUX_LAB_SOCKET" new-session -d -s lab-multistep -n probe 'exec sleep 60'
"$TMUX_BIN" -L "$TMUX_LAB_SOCKET" list-panes -t lab-multistep -F '#{pane_pid} #{pane_current_command}'
"$TMUX_BIN" -L "$TMUX_LAB_SOCKET" capture-pane -p -t lab-multistep
"$TMUX_BIN" -L "$TMUX_LAB_SOCKET" show-options -g status
''')
        script.chmod(0o700)
        process = subprocess.Popen([str(TOOL), "run", "--", str(script)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        record = wait_record(process.pid)
        out, err = process.communicate(timeout=12)
        self.assertEqual(process.returncode, 0, err + out)
        self.assertIn("sleep", out)
        self.assertTrue(independent_absence(record))
        self.assertEqual(record_for(process.pid)["state"], "closed")

    def test_signal_teardown(self):
        for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            with self.subTest(signum=signum):
                process = subprocess.Popen([str(TOOL), "run", "--", "/bin/sh", "-c", "exec sleep 60"],
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                record = wait_record(process.pid)
                os.kill(process.pid, signum)
                out, err = process.communicate(timeout=12)
                self.assertEqual(process.returncode, 128 + signum, err + out)
                self.assertTrue(independent_absence(record), str(record))

    def test_concurrent_runs(self):
        first = subprocess.Popen([str(TOOL), "run", "--", "/bin/sh", "-c", "sleep 1"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        second = subprocess.Popen([str(TOOL), "run", "--", "/bin/sh", "-c", "sleep 1"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        one = wait_record(first.pid)
        two = wait_record(second.pid)
        self.assertNotEqual(one["socket"], two["socket"])
        self.assertNotEqual(one["server_pid"], two["server_pid"])
        self.assertEqual(first.communicate(timeout=10)[0], "")
        self.assertEqual(second.communicate(timeout=10)[0], "")
        self.assertEqual(first.returncode, 0)
        self.assertEqual(second.returncode, 0)
        self.assertTrue(independent_absence(one))
        self.assertTrue(independent_absence(two))

    def test_stale_socket_is_distinct_from_live_listener(self):
        loader = importlib.machinery.SourceFileLoader("tmux_lab", str(TOOL))
        spec = importlib.util.spec_from_loader("tmux_lab", loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        path = self.output / "classification.sock"
        listener = socket.socket(socket.AF_UNIX)
        listener.bind(str(path))
        listener.listen(1)
        try:
            self.assertEqual(module.socket_state(path), "live")
        finally:
            listener.close()
        self.assertEqual(module.socket_state(path), "stale")
        print("socket classification: live listener then stale inode")
        subprocess.run(["trash", str(path)], check=True)

    def test_hup_ignoring_pane_descendant_is_removed(self):
        marker = self.output / "hup-survivor.pid"
        worker = self.output / "hup-worker.sh"
        worker.write_text('#!/bin/sh\ntrap \"\" HUP\necho $$ > "$1"\nexec sleep 60\n')
        worker.chmod(0o700)
        script = self.output / "hup-survivor.sh"
        script.write_text('#!/bin/sh\nset -eu\n"$TMUX_BIN" -L "$TMUX_LAB_SOCKET" new-session -d -s lab-survive -n child "' + str(worker) + ' ' + str(marker) + '"\nfor i in 1 2 3 4 5 6 7 8 9 10; do\n  [ -s "$1" ] && exit 0\n  sleep 0.1\ndone\nexit 9\n')
        script.chmod(0o700)
        result = subprocess.Popen([str(TOOL), "run", "--", str(script), str(marker)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        record = wait_record(result.pid)
        out, err = result.communicate(timeout=12)
        self.assertEqual(result.returncode, 0, err + out)
        closed = record_for(result.pid)
        survivor_pid = int(marker.read_text().strip())
        captured = {row["pid"] for row in closed["pane_descendants_before"]}
        self.assertIn(survivor_pid, captured)
        self.assertEqual(closed["remaining_pane_pids"], [])
        self.assertIn(survivor_pid, closed["escalated_pane_pids"])
        self.assertEqual(closed["state"], "closed")
        self.assertTrue(independent_absence(record))
        self.assertFalse(subprocess.run(["ps", "-p", str(survivor_pid), "-o", "pid="], capture_output=True, text=True).stdout.strip())
        print(f"HUP-ignoring pane PID {survivor_pid}: captured, TERM-escalated, absent")

    def test_private_tty_ctrl_c_returns_130(self):
        outer = "ccmsg-lab-private-" + str(os.getpid())
        code_file = self.output / "tty-exit-code"
        inner = "/bin/sh -c '" + str(TOOL) + " run -- /bin/sh -c \"exec sleep 60\"; echo $? > " + str(code_file) + "; exec sleep 60'"
        started = subprocess.run([REAL, "-L", outer, "-f", "/dev/null", "new-session", "-d", "-s", "lab-tty", "-n", "ctrl", inner], capture_output=True, text=True)
        self.assertEqual(started.returncode, 0, started.stderr)
        record = None
        try:
            beginning = time.time()
            for _ in range(100):
                rows = [json.loads(path.read_text()) for path in LEDGER.glob("run-*/record.json")]
                matches = [row for row in rows if row["state"] == "running" and row["created"] >= beginning - 1 and row["socket"] != outer]
                if matches:
                    record = max(matches, key=lambda row: row["created"])
                    break
                time.sleep(0.05)
            self.assertIsNotNone(record)
            sent = subprocess.run([REAL, "-L", outer, "-f", "/dev/null", "send-keys", "-t", "=lab-tty:=ctrl", "C-c"], capture_output=True, text=True)
            self.assertEqual(sent.returncode, 0, sent.stderr)
            for _ in range(100):
                if code_file.exists():
                    break
                time.sleep(0.05)
            self.assertTrue(code_file.exists())
            self.assertEqual(code_file.read_text().strip(), "130")
            print("private terminal C-c: owner exit 130")
            self.assertTrue(independent_absence(record))
        finally:
            if record and subprocess.run(["ps", "-p", str(record["owner_pid"]), "-o", "pid="], capture_output=True, text=True).stdout.strip():
                os.kill(record["owner_pid"], signal.SIGTERM)
            subprocess.run([REAL, "-L", outer, "-f", "/dev/null", "kill-server"], capture_output=True)

    def test_sigkill_stale_is_visible(self):
        marker = self.output / "sigkill-child.pid"
        command = f'echo $$ > "{marker}"; exec sleep 60'
        process = subprocess.Popen([str(TOOL), "run", "--", "/bin/sh", "-c", command], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        record = wait_record(process.pid)
        for _ in range(50):
            if marker.exists():
                break
            time.sleep(0.05)
        self.assertTrue(marker.exists())
        try:
            os.kill(process.pid, signal.SIGKILL)
            process.wait(timeout=5)
            report = subprocess.run([str(TOOL), "ls"], capture_output=True, text=True, check=True)
            rows = [json.loads(line) for line in report.stdout.splitlines()]
            row = next(row for row in rows if row["server_pid"] == record["server_pid"])
            self.assertTrue(row["stale"], report.stdout)
            self.assertFalse(independent_absence(record))
            print("SIGKILL stale detected:", json.dumps(row, sort_keys=True))
        finally:
            for _ in range(5):
                cleanup = subprocess.run([REAL, "-L", record["socket"], "-f", "/dev/null", "kill-server"], capture_output=True, text=True)
                if independent_absence(record):
                    break
                time.sleep(0.2)
            child_pid = int(marker.read_text().strip())
            try:
                os.kill(child_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
            process.stdout.close()
            process.stderr.close()
        self.assertTrue(independent_absence(record), cleanup.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
