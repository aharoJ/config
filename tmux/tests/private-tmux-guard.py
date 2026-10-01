#!/usr/bin/env python3
# path: ~/.config/tmux/tests/private-tmux-guard.py
# description: Fail closed before forwarding test traffic to an explicitly private tmux server.
# patched: reject default sockets, inherited default contexts, and unbound real tmux requests
# date: 2026-10-01
import json
import os
import pathlib
import re
import sys


def main():
    args = sys.argv[1:]
    socket = os.environ.get("STRESS_PRIVATE_SOCKET", "")
    binary = os.environ.get("STRESS_REAL_TMUX", "")
    audit = os.environ.get("STRESS_TMUX_AUDIT_LOG", "")
    if not binary or not audit:
        return 97
    if args[:1] == ["-L"]:
        if len(args) < 5 or not re.fullmatch(r"ccmsg-lab-private-[0-9]+", args[1]) or args[2:4] != ["-f", "/dev/null"]:
            return 97
        effective = args
    elif args[:1] == ["-S"] or not re.fullmatch(r"ccmsg-lab-private-[0-9]+", socket):
        return 97
    else:
        context = os.environ.get("TMUX", "").split(",")[0]
        if pathlib.Path(context).name != socket:
            return 97
        effective = ["-L", socket, "-f", "/dev/null", *args]
    if effective[4].startswith("-"):
        return 97
    record = json.dumps({"pid": os.getpid(), "binary": binary, "argv": effective}) + "\n"
    fd = os.open(audit, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    try:
        os.write(fd, record.encode())
    finally:
        os.close(fd)
    os.execv(binary, [binary, *effective])


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, IndexError):
        sys.exit(97)
