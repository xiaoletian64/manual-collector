"""Run this project's Gradle with explicit proxy properties when configured in the shell."""
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import urlparse

root = Path(__file__).resolve().parent.parent
args = [str(root / 'android/gradlew'), '-p', str(root / 'android'), '--console=plain']
for scheme in ('http', 'https'):
    proxy = os.environ.get(f'{scheme.upper()}_PROXY') or os.environ.get(f'{scheme}_proxy')
    if proxy:
        parsed = urlparse(proxy)
        if parsed.username or parsed.password:
            raise RuntimeError('Authenticated proxy: configure credentials in local Gradle settings before building')
        if parsed.scheme not in ('http', 'https') or not parsed.hostname:
            raise RuntimeError('Gradle requires an HTTP(S) proxy URL')
        args += [f'-D{scheme}.proxyHost={parsed.hostname}', f'-D{scheme}.proxyPort={parsed.port or (443 if parsed.scheme == 'https' else 80)}']
args += sys.argv[1:] or ['assembleDebug', '-Ptarget-platform=android-arm64', '-Ptarget=lib/main.dart']
raise SystemExit(subprocess.call(args, cwd=root / 'android'))
