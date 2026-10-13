from pathlib import Path

source = Path(__file__).resolve().parents[1] / "tools/test-server-cleanup"
exec(compile(source.read_bytes(), str(source), "exec"), globals())
