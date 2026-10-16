import fcntl
import os
import pty
import runpy
import select
import signal
import struct
import subprocess
import sys
import termios

helper, socket, session, ready_path = sys.argv[1:]
guard = runpy.run_path(helper)
guard["attest"](socket)
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
original = guard["run_tmux"].__globals__["_run"]
child = None

def owned_terminal():
    os.setsid()
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

def backend(argv, *args, **kwargs):
    if "attach-session" in argv:
        return subprocess.Popen(argv, stdin=slave, stdout=slave, stderr=slave, env=kwargs.get("env"), preexec_fn=owned_terminal)
    return original(argv, *args, **kwargs)

def interrupted(signum, frame):
    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, interrupted)
try:
    guard["run_tmux"].__globals__["_run"] = backend
    child = guard["run_tmux"](["tmux", "-S", socket, "attach-session", "-t", session])
    os.close(slave)
    slave = -1
    fd = os.open(ready_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(fd, str(child.pid).encode())
    os.close(fd)
    while child.poll() is None:
        readable, _, _ = select.select([master, 0], [], [], 0.1)
        if master in readable:
            try:
                os.read(master, 65536)
            except OSError:
                break
        if 0 in readable:
            line = sys.stdin.readline()
            if not line or line.strip() == "quit":
                break
            os.write(master, bytes.fromhex(line.strip()))
finally:
    if child is not None and child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=2)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(timeout=2)
    if slave >= 0:
        os.close(slave)
    os.close(master)
