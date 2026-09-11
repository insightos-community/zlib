"""Fetch only explicitly pinned release dependencies and verify before extraction."""
import hashlib
import json
import subprocess
import tarfile
from pathlib import Path
spec=json.loads(Path('/src/ci/musl/project.json').read_text())
for name, dependency in spec.get('build_dependencies', {}).items():
    archive=Path('/work') / (name + '-dependency.tar.gz')
    subprocess.run(['curl','-fL','--retry','3',dependency['url'],'-o',str(archive)],check=True)
    with archive.open('rb') as stream:
        assert hashlib.file_digest(stream,'sha256').hexdigest()==dependency['sha256'], name+' checksum mismatch'
    with tarfile.open(archive) as tar:
        tar.extractall('/work/deps',filter='data')
    manifest=json.loads(Path('/work/deps/build-manifest.json').read_text())
    assert manifest['project']==name and manifest['version']==dependency['version']
    assert manifest['source_commit']==dependency['source_commit']
    print('Verified release dependency:',name,dependency['version'],flush=True)
