#!/usr/bin/env python3


import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]
LATE_ROW = os.environ.get("TERRA_LATE_ROW", "  ⚠ Unknown warning")
RUN_LABEL = os.environ.get("TERRA_RACE_LABEL", "warning")
if not RUN_LABEL.replace("-", "").isalnum():
    raise ValueError("TERRA_RACE_LABEL must be alphanumeric with optional hyphens")
OUTPUT = Path(sys.argv[1]).resolve() / ("late-row-replace-" + RUN_LABEL)
SERVER = "ccmsg-lab-private-late-warning-" + str(os.getpid())


def tmux(*args):
    return subprocess.check_output(["tmux", "-L", SERVER, "-f", "/dev/null", *args], text=True)


def wait_for(needle, timeout=5):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        capture = tmux("capture-pane", "-p", "-e", "-t", "lab:codex")
        if needle in capture:
            return capture
        time.sleep(0.02)
    raise RuntimeError(f"timed out waiting for {needle!r}")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=False)
    case = OUTPUT / "case"
    case.mkdir()
    shutil.copytree(ROOT / "tmux/tools", case / "tools")
    actor = case / "@openai/codex/bin/codex.js"
    actor.parent.mkdir(parents=True)
    shutil.copy2(ROOT / "tmux/tests/fixtures/codex-model-1601-tui.js", actor)
    actor_source = actor.read_text().replace(
        "if (scenario === 'reset-cursor-warning' || lateWarning) rows.push('  ⚠ Unknown warning');",
        "if (scenario === 'reset-cursor-warning') rows.push('  ⚠ Unknown warning');\n"
        "    if (lateWarning) rows[4] = " + json.dumps(LATE_ROW) + ";",
    )
    actor.write_text(
        actor_source
        + "\nsetInterval(() => {\n"
        + "  if (fs.existsSync('late-warning-trigger') && !lateWarning) { lateWarning = true; draw(); }\n"
        + "}, 5);\n"
    )
    log = case / "input.jsonl"
    log.touch()
    marker = case / "glyph-probe-started"

    model_guard = case / "tools/codex-model-guard"
    model_guard_real = model_guard.with_name("codex-model-guard.real")
    model_guard.rename(model_guard_real)
    model_guard.write_text(
        "#!/bin/sh\n"
        + "[ \"$1\" != glyph ] || touch " + shlex.quote(str(marker)) + "\n"
        + "exec " + shlex.quote(str(model_guard_real)) + " \"$@\"\n"
    )
    model_guard.chmod(0o700)

    target_guard = case / "tools/codex-model-target-guard"
    target_guard_real = target_guard.with_name("codex-model-target-guard.real")
    target_guard.rename(target_guard_real)
    count = case / "target-guard-count"
    trigger = case / "late-warning-trigger"
    target_guard.write_text(
        "#!/bin/sh\n"
        + "count_file=" + shlex.quote(str(count)) + "\n"
        + "count=0\n"
        + "[ ! -f \"$count_file\" ] || count=$(cat \"$count_file\")\n"
        + "count=$((count + 1))\n"
        + "printf '%s\\n' \"$count\" > \"$count_file\"\n"
        + shlex.quote(str(target_guard_real)) + " \"$@\"\n"
        + "code=$?\n"
        + "if [ \"$count\" -eq 2 ] && [ \"$code\" -eq 0 ]; then\n"
        + "  touch " + shlex.quote(str(trigger)) + "\n"
        + "  sleep 0.15\n"
        + "fi\n"
        + "exit \"$code\"\n"
    )
    target_guard.chmod(0o700)

    command = shlex.join(
        ["node", str(actor), "~/model-lab/late-warning-race", str(log), "reset-cursor-settles", str(marker)]
    )
    result = {}
    try:
        tmux("new-session", "-d", "-s", "lab", "-n", "codex", "-x", "200", "-y", "50", "-c", str(case), "exec " + command)
        wait_for("Ask Codex")
        tmux("send-keys", "-t", "lab:codex", "-l", "/new")
        tmux("send-keys", "-t", "lab:codex", "Enter")
        wait_for("Where should")
        tmux("send-keys", "-t", "lab:codex", "Enter")
        wait_for("Context 0% used")
        prefix = log.read_text().splitlines()
        env = dict(
            os.environ,
            TMUX=tmux("display-message", "-p", "-t", "lab:codex", "#{socket_path},#{pid},0").strip(),
            CODEX_SEND_SESSION="lab",
            TMPDIR=str(case),
            TMUX_RELAY_LOCK_ROOT=str(case / "locks"),
        )
        process = subprocess.run(
            [str(case / "tools/codex-model"), "lab", "codex", "gpt-6.1-sol", "low"],
            env=env,
            text=True,
            capture_output=True,
            timeout=90,
        )
        capture = tmux("capture-pane", "-p", "-e", "-t", "lab:codex")
        inputs = log.read_text().splitlines()[len(prefix):]
        result = {
            "late_row": LATE_ROW,
            "exit": process.returncode,
            "inputs": inputs,
            "warning_triggered": trigger.exists(),
            "warning_present_after": "Unknown warning" in capture,
            "stdout": process.stdout,
            "stderr": process.stderr,
            "secure": process.returncode == 5 and not inputs,
        }
    finally:
        subprocess.run(["tmux", "-L", SERVER, "kill-server"], capture_output=True)
    (OUTPUT / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return 0 if result.get("secure") else 1


if __name__ == "__main__":
    sys.exit(main())
