import json
import os
import re
import subprocess
from pathlib import Path
prefix=Path('/work/prefix')
rows=[]
for path in sorted(prefix.rglob('*')):
    if not path.is_file() or path.is_symlink():
        continue
    with path.open('rb') as stream:
        if stream.read(4)!=b'\x7fELF':
            continue
    dynamic=subprocess.check_output(['readelf','-d',str(path)],text=True)
    versions=subprocess.check_output(['readelf','--version-info',str(path)],text=True)
    ldd=subprocess.run(['ldd',str(path)],capture_output=True,text=True)
    rows.append({'path':str(path.relative_to(prefix)),
        'needed':re.findall(r'\(NEEDED\).*?\[(.*?)\]',dynamic),
        'glibc_versions':sorted(set(re.findall(r'\bGLIBC_[0-9.]+',versions))),
        'ldd_returncode':ldd.returncode,'ldd_stdout':ldd.stdout,'ldd_stderr':ldd.stderr})
Path('/work/logs/elf-audit.json').write_text(json.dumps(rows,indent=2)+'\n')
assert rows
assert not [r for r in rows if r['glibc_versions'] or r['ldd_returncode']]
print(f'PASS: {len(rows)} built ELF files, no GLIBC symbol versions or unresolved dependencies')
