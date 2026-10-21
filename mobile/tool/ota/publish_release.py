"""Publish a prepared release to the existing server; APK first, manifest last."""
import argparse, hashlib, json, pathlib, re, subprocess, uuid
p = argparse.ArgumentParser()
p.add_argument('release_dir', type=pathlib.Path)
p.add_argument('--host', default='wo_fuwuqi')
a = p.parse_args()
if not re.fullmatch(r'[A-Za-z0-9_.@-]+', a.host) or a.host.startswith('-'):
    raise SystemExit('Invalid SSH host')
data = json.loads((a.release_dir / 'latest.json').read_text())
name = data['apkUrl']
if not re.fullmatch(r'manual-collector-\d+\.apk', name):
    raise SystemExit('Unexpected APK filename')
source = a.release_dir / name
h = hashlib.sha256()
with source.open('rb') as f:
    for chunk in iter(lambda: f.read(1048576), b''): h.update(chunk)
if h.hexdigest() != data['sha256'] or source.stat().st_size != data['size']:
    raise SystemExit('Local artifact failed checksum')
root = '/www/server/nginx/html/manual-collector/android'
stage = '.staging-' + uuid.uuid4().hex
subprocess.run(['ssh', '-o', 'BatchMode=yes', a.host, f'mkdir -p {root}/{stage}'], check=True)
subprocess.run(['scp', '-o', 'BatchMode=yes', str(source), str(a.release_dir / 'latest.json'), f'{a.host}:{root}/{stage}/'], check=True)
script = r'''
import fcntl, hashlib, json, os, pathlib, sys
root = pathlib.Path(sys.argv[1]); stage = root / sys.argv[2]
with (root / '.publish.lock').open('w') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    data = json.loads((stage / 'latest.json').read_text())
    name = data['apkUrl']; apk = stage / name
    assert '/' not in name and name.endswith('.apk')
    h = hashlib.sha256()
    with apk.open('rb') as f:
        for chunk in iter(lambda: f.read(1048576), b''): h.update(chunk)
    assert h.hexdigest() == data['sha256'] and apk.stat().st_size == data['size']
    manifest = root / 'latest.json'
    if manifest.exists():
        old = json.loads(manifest.read_text())
        assert data['versionCode'] >= old['versionCode'], 'Refusing downgrade'
        if data['versionCode'] == old['versionCode']:
            assert data['sha256'] == old['sha256'], 'Build number reused with different content'
    os.chmod(apk, 0o644)
    os.chmod(stage / 'latest.json', 0o644)
    os.replace(apk, root / name)
    os.replace(stage / 'latest.json', manifest)
    stage.rmdir()
    print('Published', data['versionName'], data['versionCode'], data['sha256'])
'''
subprocess.run(['ssh', '-o', 'BatchMode=yes', a.host, f'python3 - {root} {stage}'], input=script, text=True, check=True)
