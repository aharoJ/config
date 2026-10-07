import concurrent.futures
import json
from pathlib import Path
import subprocess
import sys
import time

mode, path = sys.argv[1:]
path = Path(path)
if mode == 'client':
    path.with_suffix('.ready').touch()
    until = time.monotonic() + 55
    result = path.with_suffix('.result')
    while not result.exists():
        if time.monotonic() > until:
            raise TimeoutError(str(path))
        time.sleep(.02)
    data = json.loads(result.read_text())
    sys.stdout.write(data['stdout'])
    sys.stderr.write(data['stderr'])
    sys.exit(data['returncode'])
else:
    def execute(request):
        data = json.loads(request.read_text())
        try:
            result = subprocess.run(data['argv'], env=data['env'], text=True, capture_output=True, timeout=45)
            value = dict(returncode=result.returncode, stdout=result.stdout, stderr=result.stderr)
        except Exception as error:
            value = dict(returncode=99, stdout='', stderr=repr(error))
        temporary = request.with_suffix('.tmp')
        temporary.write_text(json.dumps(value))
        temporary.rename(request.with_suffix('.result'))

    seen = set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        while True:
            for ready in path.glob('*.ready'):
                if ready not in seen:
                    seen.add(ready)
                    pool.submit(execute, ready.with_suffix('.json'))
            time.sleep(.02)
