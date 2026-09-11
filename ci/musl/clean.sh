#!/bin/sh
set -eu
exec > /work/logs/clean-install.log 2>&1
mkdir -p /opt/check /opt/dependency /opt/compiler-runtime
# Extract the actual release archive at a different path, not the build prefix.
tar -xzf /work/dist/*-musl-x86_64-prefix.tar.gz -C /opt/check
cp /work/compiler-runtime/* /opt/compiler-runtime/
if [ -f /work/zlib-dependency.tar.gz ]; then
  tar -xzf /work/zlib-dependency.tar.gz -C /opt/dependency
fi
cp /work/smoke /opt/check/smoke
export LD_LIBRARY_PATH=/opt/check/prefix/lib:/opt/dependency/prefix/lib:/opt/compiler-runtime
/opt/check/smoke
python - <<'PYCODE'
import ctypes
import json
from pathlib import Path
spec=json.loads(Path('/src/ci/musl/project.json').read_text())
ctypes.CDLL('/opt/check/prefix/lib/'+spec['library'])
loaded=sorted({line.split()[-1] for line in Path('/proc/self/maps').read_text().splitlines() if '/' in line})
assert any(p.startswith('/opt/check/prefix/lib/') for p in loaded)
assert not any(p.startswith('/work/') for p in loaded),loaded
print(json.dumps({'loaded_libraries':loaded},indent=2))
print('PASS: clean offline container, relocated release archive')
PYCODE
