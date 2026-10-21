"""Cache the exact PDFium release required by the locked plugin, using curl's proxy support.

The plugin's Dart HTTP downloader can fail TLS handshakes behind a system proxy.
This fills only this project's build cache; it does not patch the plugin or disable TLS.
"""
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
from urllib.parse import urlparse, unquote

root = Path(__file__).resolve().parent.parent
config = json.loads((root / '.dart_tool/package_config.json').read_text())
package = next(p for p in config['packages'] if p['name'] == 'pdfium_dart')
uri = urlparse(package['rootUri'])
if uri.scheme != 'file':
    raise RuntimeError('Expected a local pub-cache package for pdfium_dart')
hook = Path(unquote(uri.path)) / 'hook/build.dart'
match = re.search(r"const _pdfiumRelease = '([^']+)';", hook.read_text())
if not match:
    raise RuntimeError('PDFium hook changed; review the dependency before preparing its cache')
release = match.group(1)
output = root / '.dart_tool/hooks_runner/shared/pdfium_dart/build' / release.replace('%2F', '_') / 'android-arm64/libpdfium.so'
if not output.exists():
    url = f'https://github.com/bblanchon/pdfium-binaries/releases/download/{release}/pdfium-android-arm64.tgz'
    with tempfile.TemporaryDirectory(prefix='manual-pdfium-') as temp:
        archive_path = Path(temp) / 'pdfium.tgz'
        subprocess.run(['curl', '--fail', '--location', '--retry', '2', '--max-time', '120', url, '-o', str(archive_path)], check=True)
        with tarfile.open(archive_path) as archive:
            library = archive.extractfile('lib/libpdfium.so')
            if library is None:
                raise RuntimeError('Release archive contains no Android PDFium library')
            data = library.read()
        if not data.startswith(b'\x7fELF'):
            raise RuntimeError('Invalid shared library in release archive')
        output.parent.mkdir(parents=True, exist_ok=True)
        temporary = output.with_suffix('.tmp')
        temporary.write_bytes(data)
        temporary.replace(output)
print(f'PDFium {release}: Android ARM64 build cache ready')
