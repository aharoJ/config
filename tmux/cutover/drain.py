import argparse
import json
import os
from pathlib import Path
import re
import runpy
import shlex
import stat
import subprocess
import time

SURFACES = {"relay", "cc-msg", "cc-msg.sh", "codex-send", "codex-send-to", "agy-send-to", "cc-msg-queue", "codex-model", "codex-new-chat", "relay-clear-draft"}


def observe(arguments, allow_absent=False):
    process = subprocess.Popen(arguments, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        output, error = process.communicate(timeout=3)
    except subprocess.TimeoutExpired as failure:
        raise RuntimeError(f"observation unresolved; stop checks; child {process.pid}") from failure
    if process.returncode and not (allow_absent and process.returncode == 1 and error.startswith(b"unknown variable:") and not output):
        raise RuntimeError(f"observation refused: {arguments[0]}")
    return output.decode()


def sender_processes(text):
    senders = []
    for line in text.splitlines():
        fields = line.split(None, 2)
        if len(fields) != 3:
            continue
        possible = any(Path(word.strip("'\"")).name in SURFACES | {"relay-core", "angelstar-runtime", "launch"} for word in fields[2].split())
        try:
            arguments = shlex.split(fields[2])
        except ValueError:
            if possible:
                raise ValueError("unreadable possible sender argv")
            continue
        classified = False
        indices = [0] if arguments else []
        if arguments and (Path(arguments[0]).name.startswith("python") or Path(arguments[0]).name in {"bash", "sh", "zsh", "fish"}):
            for index, argument in enumerate(arguments[1:], 1):
                if argument in {"-c", "-m"}:
                    break
                if not argument.startswith("-"):
                    indices.append(index)
                    break
        for index in indices:
            argument = arguments[index]
            name = Path(argument).name
            if name == "relay-core" and arguments[index + 1:index + 2] == ["--deliver"]:
                classified = True
                senders.append({"pid": int(fields[0]), "kind": "python", "record": arguments[index + 2:index + 3]})
            if name == "cc-msg-queue" and arguments[index + 1:index + 2] in (["--worker"], ["--schedule"], ["--watch-worker"]):
                senders.append({"pid": int(fields[0]), "kind": "legacy-queue"})
            dispatcher = name == "launch" and (Path(argument).parent / "transport.json").is_file()
            if name in SURFACES or dispatcher:
                classified = True
                tail = arguments[index + 1:]
                if tail in (["--help"], ["-h"]) or (name == "relay" and (not tail or tail[0] in {"status", "read"})):
                    continue
                senders.append({"pid": int(fields[0]), "kind": "pre-handoff"})
            if name == "angelstar-runtime":
                classified = True
                tail = arguments[index + 1:]
                if tail[:1] != ["--surface"] or len(tail) < 2:
                    raise ValueError("unrecognized runtime argv")
                surface, words = tail[1], tail[2:]
                if words in (["--help"], ["-h"]) or (surface == "relay" and (not words or words[0] in {"status", "read"})):
                    continue
                senders.append({"pid": int(fields[0]), "kind": "rust"})
        if possible and not classified:
            raise ValueError("unclassified possible sender argv")
    return senders


def target_locks(socket, panes, server_generation, generation):
    active, retired = [], []
    for path in socket.parent.glob("target-*"):
        metadata = path.lstat()
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.geteuid() or stat.S_IMODE(metadata.st_mode) != 0o600:
            raise ValueError("unsafe target lock")
        if not metadata.st_size:
            continue
        match = re.fullmatch(r"target-(\d+)-(\d+)-(\d+)", path.name)
        if match is None:
            raise ValueError("unrecognized target lock")
        server, pane, process = map(int, match.groups())
        pid = panes.get(f"%{pane}")
        if server != server_generation or pid is None:
            retired.append(str(path))
        else:
            seconds, micros = generation(int(pid))
            (active if seconds * 1000000 + micros == process else retired).append(str(path))
    return active, retired


def legacy_records(roots, live_panes, namespace=None):
    counts = {}
    blockers = []
    retired_errors = []
    for root in roots:
        if not root.is_absolute() or root.resolve() != root:
            raise ValueError("noncanonical legacy root")
        for path in root.glob("*/*.json"):
            value = json.loads(path.read_text())
            if not isinstance(value, dict) or not {"id", "state"} <= value.keys():
                raise ValueError("unrecognized inbox record")
            state = value["state"]
            counts[state] = counts.get(state, 0) + 1
            if path.name.endswith(".watch.json") and set(value) <= {"id", "state", "time", "record"} and state in {"output-observed", "notification-queued"}:
                continue
            if "target" in value:
                target = value["target"]
                terminal = state == "error"
            elif ("identity" in value and {"session", "window"} <= value.keys()) or value.get("operation") == "clear-draft":
                identity = value.get("identity") or {}
                target = {"pane_id": identity.get("pane"), "pane_pid": identity.get("pid")}
                terminal = state in {"failed", "unknown", "expired", "cleared", "clear-refused"}
                if namespace and (identity.get("device"), identity.get("inode")) != namespace:
                    target = {}
                if state == "failed" and not identity and value.get("code") in {1, 2, 5}:
                    terminal = True
            else:
                raise ValueError("unrecognized inbox record")
            record = {"id": value["id"], "state": state, "path": str(path), "pane": target.get("pane_id")}
            if state == "delivered":
                continue
            if terminal and live_panes.get(target.get("pane_id")) != str(target.get("pane_pid")):
                retired_errors.append(record)
            else:
                blockers.append(record)
    return {"counts": counts, "blockers": blockers, "retained_terminal_no_replay": retired_errors}


def rust_store(path):
    if not path.exists():
        raise ValueError("production store is not prepared")
    metadata = path.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != os.geteuid() or stat.S_IMODE(metadata.st_mode) != 0o700:
        raise ValueError("unsafe production store")
    ledger = json.loads((path / "ledger.json").read_text())
    if ledger.get("schema") != "angelstar-store" or ledger.get("version") != 1:
        raise ValueError("unrecognized production store")
    blockers = []
    for attempt in ledger["attempts"]:
        history = attempt.get("history")
        if not history:
            raise ValueError("missing attempt history")
        state = history[-1]["state"]
        if state not in {"submitted", "terminal-no-input"}:
            blockers.append({"id": attempt["id"], "state": state})
    return {"path": str(path), "revision": ledger["revision"], "attempts": len(ledger["attempts"]), "blockers": blockers}


def collect(socket, roots, store):
    if not socket.is_absolute() or socket.resolve(strict=True) != socket:
        raise ValueError("canonical socket required")
    metadata = socket.lstat()
    if not stat.S_ISSOCK(metadata.st_mode) or metadata.st_uid != os.geteuid():
        raise ValueError("owned socket required")
    helper = Path(__file__).resolve().parents[1] / "tests/cleanup_guard.py"
    generation = runpy.run_path(str(helper))["generation"]
    def tmux(*arguments, allow_absent=False):
        return observe(["/opt/homebrew/bin/tmux", "-N", "-S", str(socket), *arguments], allow_absent).strip()
    identity = tmux("display-message", "-p", "#{socket_path}|#{pid}|#{start_time}")
    fields = identity.split("|")
    if len(fields) != 3 or fields[0] != str(socket):
        raise ValueError("server identity mismatch")
    server_generation = generation(int(fields[1]))
    roots = set(roots)
    if os.environ.get("CC_MSG_INBOX_ROOT"):
        roots.add(Path(os.environ["CC_MSG_INBOX_ROOT"]))
    scopes = [None] + tmux("list-sessions", "-F", "#{session_name}").splitlines()
    for session in scopes:
        arguments = ["show-environment", "-g"] if session is None else ["show-environment", "-t", "=" + session]
        environment = tmux(*arguments, "CC_MSG_INBOX_ROOT", allow_absent=True)
        for line in environment.splitlines():
            if line.startswith("CC_MSG_INBOX_ROOT="):
                roots.add(Path(line.partition("=")[2]))
    rows = tmux("list-panes", "-a", "-F", "#{pane_id}\t#{pane_pid}").splitlines()
    panes = dict(row.split("\t") for row in rows)
    legacy = legacy_records(sorted(roots), panes, (metadata.st_dev, metadata.st_ino))
    runtime = rust_store(store)
    processes = sender_processes(observe(["/bin/ps", "-axo", "pid=,ppid=,command="]))
    locks, retired_locks = target_locks(socket, panes, server_generation[0] * 1000000 + server_generation[1], generation)
    after = socket.lstat()
    if identity != tmux("display-message", "-p", "#{socket_path}|#{pid}|#{start_time}") or generation(int(fields[1])) != server_generation or (metadata.st_dev, metadata.st_ino) != (after.st_dev, after.st_ino):
        raise ValueError("server changed during drain")
    return {"schema": "relay-drain-1", "checked_at": time.time(), "socket": str(socket), "server_pid": int(fields[1]), "server_generation": server_generation, "socket_device": metadata.st_dev, "socket_inode": metadata.st_ino, "roots": [str(root) for root in sorted(roots)], "legacy": legacy, "rust": runtime, "senders": processes, "unsettled_target_locks": locks, "retired_target_locks_retained": retired_locks, "clear": not (legacy["blockers"] or runtime["blockers"] or processes or locks)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket", required=True, type=Path)
    parser.add_argument("--inbox", required=True, action="append", type=Path)
    parser.add_argument("--store", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    result = collect(arguments.socket, arguments.inbox, arguments.store)
    arguments.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"clear": result["clear"], "evidence": str(arguments.output)}))
    return 0 if result["clear"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
