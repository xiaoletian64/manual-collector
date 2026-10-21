"""Create a static OTA release tree. Does not upload or modify any server."""
import argparse, hashlib, json, pathlib, re, shutil, subprocess
p = argparse.ArgumentParser()
p.add_argument('apk', type=pathlib.Path)
p.add_argument('--aapt', required=True)
p.add_argument('--output', type=pathlib.Path, required=True)
p.add_argument('--notes', required=True)
a = p.parse_args()
metadata = subprocess.check_output([a.aapt, 'dump', 'badging', str(a.apk)], text=True)
m = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", metadata)
if not m or m[1] != 'com.manualcollector.manual_collector':
    raise SystemExit('Wrong APK package')
root = a.output / 'manual-collector' / 'android'
root.mkdir(parents=True, exist_ok=True)
name = f'manual-collector-{m[2]}.apk'
target = root / name
def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()
hash_value = digest(a.apk)
if target.exists() and digest(target) != hash_value:
    raise SystemExit('This versionCode already has a different APK; bump the build number')
shutil.copy2(a.apk, target)
data = dict(packageName=m[1], versionCode=int(m[2]), versionName=m[3], apkUrl=name,
            sha256=hash_value, size=a.apk.stat().st_size, notes=a.notes)
tmp = root / 'latest.json.tmp'
tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
tmp.replace(root / 'latest.json')
print(root)
