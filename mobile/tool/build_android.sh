#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
flutter_command="${FLUTTER_BIN:-flutter}"
if ! command -v "$flutter_command" >/dev/null 2>&1; then
  flutter_sdk="$(sed -n 's/^flutter.sdk=//p' android/local.properties)"
  flutter_command="$flutter_sdk/bin/flutter"
fi
"$flutter_command" pub get
python3 tool/prepare_pdfium.py
# Use the terminal's Java rather than an Intel Android Studio JBR on Apple Silicon.
if [[ -z "${JAVA_HOME:-}" && "$(uname -s)" == Darwin ]]; then
  export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
fi
python3 tool/run_gradle.py
