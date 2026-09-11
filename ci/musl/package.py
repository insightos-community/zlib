import hashlib
import json
import re
import shutil
import subprocess
import tarfile
from pathlib import Path
work=Path('/work')
source=Path('/src')
spec=json.loads((source/'ci/musl/project.json').read_text())
licenses=work/'licenses'
licenses.mkdir(exist_ok=True)
for path in source.rglob('*'):
    if path.is_file() and '.git' not in path.parts and re.match(r'^(LICENSE|COPYING|COPYRIGHT)(\.|$)',path.name,re.I):
        destination=licenses/path.relative_to(source)
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(path,destination)
rows=json.loads((work/'logs/elf-audit.json').read_text())
manifest={**spec,
    'source_commit':subprocess.check_output(['git','-C','/src','rev-parse','HEAD'],text=True).strip(),
    'platform':'linux-musl-x86_64',
    'artifact_kind':'installed prefix of shared library and development files; not a complete runtime',
    'base_image':'python:3.13-alpine3.23@sha256:75f27d686432419c9d42420b2b9ef605868c7a0682a6be10a6601fad46c2df01',
    'built_elf_files_checked':len(rows),
    'elf_needed':{r['path']:r['needed'] for r in rows},
    'glibc_symbol_requirements':[],
    'apk_packages':(work/'logs/apk-packages.txt').read_text().splitlines(),
    'tests':(work/'logs/tests.log').read_text().splitlines()[-8:],
}
dist=work/'dist'
(dist/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
archive=dist/f"{spec['project']}-{spec['version']}-musl-x86_64-prefix.tar.gz"
with tarfile.open(archive,'w:gz') as tar:
    tar.add(work/'prefix',arcname='prefix')
    tar.add(licenses,arcname='licenses')
    tar.add(dist/'build-manifest.json',arcname='build-manifest.json')
    tar.add(source/'ci/musl/README.md',arcname='README.md')
shutil.copyfile(source/'ci/musl/README.md',dist/'RELEASE_NOTES.md')
checksums=[]
for path in [archive,dist/'build-manifest.json']:
    with path.open('rb') as stream:
        digest=hashlib.file_digest(stream,'sha256').hexdigest()
    checksums.append(f'{digest}  {path.name}')
(dist/'SHA256SUMS').write_text('\n'.join(checksums)+'\n')
print('\n'.join(checksums))
