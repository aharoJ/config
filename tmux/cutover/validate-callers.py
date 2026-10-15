import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re


parser = argparse.ArgumentParser()
parser.add_argument("manifest", type=Path)
parser.add_argument("--home", type=Path, default=Path.home())
args = parser.parse_args()
manifest = json.loads(args.manifest.read_text())
assert manifest["schema"] == "relay-caller-migration" and manifest["version"] == 1
entries = manifest["entries"]
by_path = {entry["path"]: entry for entry in entries}
assert len(by_path) == len(entries)
assert len({entry["stagedpath"] for entry in entries}) == len(entries)
for entry in entries:
    source = Path(entry["path"])
    target = Path(entry["stagedpath"])
    relative = source.relative_to(args.home)
    assert target.parts[-len(relative.parts):] == relative.parts, target
    before = source.read_bytes()
    after = target.read_bytes()
    assert hashlib.sha256(before).hexdigest() == entry["beforehash"], source
    assert hashlib.sha256(after).hexdigest() == entry["afterhash"], target
    assert before != after, source
    text = after.decode()
    original = before.decode()
    assert text.count("```") % 2 == original.count("```") % 2, target
    assert text.count("## Installed transport contract") <= 1, target
    assert not re.search(r"Exit 6 means (?:the queue owns|queue-owned)|exit 6 is queue-owned|Exit 6 is\s*queued", text), target
    assert ".config/scripts/cc-msg.sh" not in text, target
    assert not re.search(r"check (?:the record's )?target\.session_name", text), target
    assert text.count(".,") <= original.count(".,"), target
    assert text.count(".;") <= original.count(".;"), target
for source in (args.home / ".claude/projects").glob("*/memory/*.md"):
    if str(source) not in by_path:
        assert not re.search(r"Exit 6|exit 6|queue owns|check.*target\.session_name|honor refusals and queue ownership|Delivery/queue ownership|exit 3/4 remains uncertain|uncertain/queue-owned message", source.read_text()), source
skill_roots = [args.home / ".skills/review-protocol"]
skill_roots += list((args.home / ".skills/review-protocol-wt").glob("*"))
for root in skill_roots:
    for relative in ["CLAUDE.md", ".claude/codex-addressing.md", "notes/codex-desk/watch-setup.md"]:
        source = root / relative
        if source.is_file() and "codex-send" in source.read_text():
            assert str(source) in by_path, source
            text = Path(by_path[str(source)]["stagedpath"]).read_text()
            assert "CODEX_SEND_SESSION=" in text, source
            assert "Rust" in text and "legacy" in text.lower(), source
assert str(args.home / ".codex/AGENTS.md") in by_path
print(json.dumps({"entries": len(entries), "hashes": "verified", "active_copy_coverage": "verified",
                  "staged_groups": dict(Counter(Path(entry["path"]).name for entry in entries))}, sort_keys=True))
