#!/usr/bin/env python3
# path: ~/.config/tmux/tests/relay-fuzz-regression.py
# description: Seeded hostile payload, composer, footer, and ancestry properties.
# patched: fuzz Agy's prompt, footer, and draft boundary
# date: 2026-10-02T04:00:00Z
import argparse
import json
import os
import pathlib
import random
import re
import subprocess
import sys
import tempfile
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(seed, iterations, output):
    rng = random.Random(seed)
    failures = []
    counts = {"normalization": 0, "payload": 0, "input": 0, "sender": 0}
    with tempfile.TemporaryDirectory(prefix="relay-fuzz-") as temporary:
        directory = pathlib.Path(temporary)
        payload = directory / "payload"
        pane_list = directory / "panes"
        bin_dir = directory / "bin"
        bin_dir.mkdir()
        state = directory / "ps.json"
        ps = bin_dir / "ps"
        ps.write_text("#!" + sys.executable + "\nimport json, os, sys\ns=json.load(open(os.environ['FUZZ_PS_STATE']))\nprint(s['table'] if '-ax' in sys.argv else s.get('args',''))\n")
        ps.chmod(0o755)
        env = {**os.environ, "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"], "FUZZ_PS_STATE": str(state),
               "TMUX_PANE": "%99999", "CC_MSG_FROM": "spoofed"}

        def check(group, command, data, expected, expected_stdout=None):
            result = subprocess.run(command, input=data, capture_output=True, timeout=3, env=env)
            counts[group] += 1
            if result.returncode != expected or (expected_stdout is not None and result.stdout != expected_stdout):
                failures.append({"group": group, "iteration": i, "argv": command[1:], "stdin": data.decode(errors="backslashreplace"),
                                 "exit": result.returncode, "expected_exit": expected, "stdout": result.stdout.decode(errors="backslashreplace"),
                                 "stderr": result.stderr.decode(errors="backslashreplace")})

        guard = str(ROOT / "tools/relay-payload-guard")
        input_guard = str(ROOT / "tools/relay-input-guard")
        label = str(ROOT / "tools/relay-sender-label")
        safe = "abcXYZ012 -$`'\\;#{}()é漢😀\u00a0\u0301"
        hostile = "\x00\x01\x1b\x7f\u0085\u202e\u200b\u200d\u2028\u2029"
        for i in range(iterations):
            text = "".join(rng.choice(safe + "\n\r\t" + hostile) for _ in range(rng.randrange(0, 45)))
            valid = not any(unicodedata.category(c) in ("Cc", "Cf", "Cs", "Zl", "Zp") and c not in "\n\r\t" for c in text)
            normalized = re.sub(" +", " ", text.replace("\n", " ").replace("\r", " ").replace("\t", " ")).strip(" ")
            check("normalization", [guard, "normalize"], text.encode(), 0 if valid else 1,
                  normalized.encode() if valid else b"")
            if i % 10 == 0:
                check("normalization", [guard, "normalize"], b"invalid\xff\xfe", 2, b"")

            value = "v" + "".join(rng.choice(safe) for _ in range(rng.randrange(0, 35))) + "z"
            payload.write_text(value)
            cells = sum(0 if unicodedata.combining(c) else 2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in value)
            glyph = rng.choice(("›", "❯"))
            if glyph == "❯":
                capture = "─" * 80 + "\n❯ " + value + "\n" + "─" * 80 + "\n"
                row = 1
            else:
                capture = "› " + value + "\n\n  Fast off · GPT-6.1-Sol high · ~/lab · Context 0% used\n"
                row = 0
            check("payload", [guard, "compare", glyph, str(cells + 2), str(row), str(payload), "80"], capture.encode(), 0)
            check("payload", [guard, "compare", glyph, str(cells + 3), str(row), str(payload), "80"], capture.encode(), 1)
            check("payload", [guard, "compare", glyph, str(cells + 2), str(row), str(payload), "80"], capture.replace(value, value + "extra", 1).encode(), 1)
            check("payload", [guard, "capacity", str(payload), str(cells + 3)], b"", 1)
            check("payload", [guard, "capacity", str(payload), str(cells + 4)], b"", 0)

            footer = "\x1b[49m  Fast off · test · Context 0% used" if glyph == "›" else "─" * 80
            if glyph == "›" and rng.randrange(2):
                footer += " · Main [default]"
            if glyph == "›":
                placeholder = glyph + " \x1b[2mAsk Codex to do anything\x1b[0m\n" + footer + "\n"
                dim_text = glyph + " \x1b[2m" + value + "\x1b[22m\n" + footer + "\n"
                check("input", [input_guard, glyph, "2", "0"], placeholder.encode(), 0)
                check("input", [input_guard, glyph, "3", "0"], placeholder.encode(), 0)
                check("input", [input_guard, glyph, "2", "0"], dim_text.encode(), 0)
                check("input", [input_guard, glyph, "2", "0"], (glyph + "\n" + footer + "\n").encode(), 1)
                check("input", [input_guard, glyph, "2", "0"],
                      (glyph + " \x1b[2mAsk Codex to do anything\x1b[0m\n    \n" + footer + "\n").encode(), 1)
                check("input", [input_guard, glyph, "2", "0"],
                      (glyph + " \x1b[2mAsk Codex to do anything\x1b[0m\n\x1b[49m\x1b[0;08m  Fast off · test · Context 0% used\x1b[0m\n").encode(), 1)
                check("input", [input_guard, glyph, "2", "0"],
                      (glyph + " \x1b[2mAsk Codex to do anything\x1b[0m\n\x1b[49m\x1b[2J  Fast off · test · Context 0% used\n").encode(), 1)
            else:
                empty = glyph + "\u00a0\n" + footer + "\n  Opus 5.5 | v2.1.287\n  ⏵⏵ bypass permissions on\n"
                dim_text = glyph + " \x1b[2m" + value + "\x1b[22m\n" + footer + "\n"
                whitespace = glyph + "    \n" + footer + "\n"
                continuation = glyph + "\u00a0\n\x1b[2m  " + value + "\x1b[22m\n" + footer + "\n"
                check("input", [input_guard, glyph, "2", "0"], empty.encode(), 0)
                check("input", [input_guard, glyph, "3", "0"], empty.encode(), 0)
                check("input", [input_guard, glyph, "2", "0"], dim_text.encode(), 0)
                check("input", [input_guard, glyph, "2", "0"], whitespace.encode(), 1)
                check("input", [input_guard, glyph, "2", "0"], continuation.encode(), 1)
                check("input", [input_guard, glyph, "2", "0"],
                      (glyph + "\u00a0\n    \n" + footer + "\n").encode(), 1)
                check("input", [input_guard, glyph, "2", "0"],
                      (glyph + "\x1b[08m\u00a0\x1b[0m\n" + footer + "\n").encode(), 1)
                check("input", [input_guard, glyph, "2", "0"],
                      (glyph + "\u00a0\n\x1b[0008m" + footer + "\x1b[0m\n").encode(), 1)
                check("input", [input_guard, glyph, "2", "0"],
                      (glyph + "\u00a0\n\x1b[2J" + footer + "\n").encode(), 1)
            check("input", [input_guard, glyph, "2", "0"], (glyph + " " + value + "\n" + footer + "\n").encode(), 1)
            check("input", [input_guard, glyph, "3", "0"], (glyph + " " + value + "\n" + footer + "\n").encode(), 1)
            agy_divider = "─" * 80
            agy_idle = agy_divider + "\n\x1b[94m>\x1b[39m\n" + agy_divider + "\n? for shortcuts  Gemini 3.8 Flash · high\n"
            agy_draft = agy_idle.replace("\x1b[94m>\x1b[39m\n", "\x1b[94m>\x1b[39m " + value + "\n", 1)
            check("input", [input_guard, ">", "2", "1", "80"], agy_idle.encode(), 0)
            check("input", [input_guard, ">", "2", "1", "80"], agy_draft.encode(), 1)
            if glyph == "›":
                malformed = rng.choice(("\x1b[49m  continuation", "\x1b[38;5;215m  Fast unknown · Draft Context", "\x1b[49m  Fast off", "\x1b[49m  Fast off · test · Context 0% used · Main [other]"))
                check("input", [input_guard, glyph, "2", "0"], (glyph + " \n" + malformed + "\n").encode(), 1)
                check("payload", [guard, "compare", glyph, str(cells + 2), "0", str(payload), "80"], (glyph + " " + value + "\n" + malformed + "\n").encode(), 1)

            session = "lab-" + str(rng.randrange(100000))
            window = "lab_" + str(rng.randrange(100000))
            agent = rng.choice(("claude", "codex", "unknown"))
            panes = f"%13 {session} {window} node 8000 0\n"
            invalid = rng.randrange(5)
            if invalid == 0:
                panes += panes
            elif invalid == 1:
                panes = panes.replace(session, "bad session")
            elif invalid == 2:
                panes = panes.replace("8000 0", "8000 1")
            pane_list.write_text(panes)
            state.write_text(json.dumps({"table": f"9000 8000 /lab/{agent}\n8000 1 /bin/fish\n"}))
            expected = b"" if invalid < 3 else f"%13 {session} {window} 8000 {agent if agent != 'unknown' else 'relay'}\n".encode()
            check("sender", [label, "9000", str(pane_list)], b"", 0, expected)
    result = {"seed": seed, "iterations": iterations, "counts": counts, "failures": failures}
    if output:
        pathlib.Path(output).write_text(json.dumps(result, indent=2))
    print(json.dumps({"seed": seed, "iterations": iterations, "counts": counts, "failures": len(failures)}))
    return 1 if failures else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20260930)
    parser.add_argument("--iterations", type=int, default=300)
    parser.add_argument("--output")
    args = parser.parse_args()
    sys.exit(run(args.seed, args.iterations, args.output))
