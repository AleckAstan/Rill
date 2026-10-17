#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
./scripts/build.sh
./scripts/test.sh
swift test --package-path Packages/RillExtensionKit
swift build -c release --package-path Examples/extensions/RichSample
./scripts/release.sh
./scripts/prepare-homebrew.sh
./scripts/verify-release.sh
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
app=".build/releases/Rill-$version.xcarchive/Products/Applications/Rill.app"
python3 - "$app" <<'PY'
from pathlib import Path
import subprocess
import sys
app = Path(sys.argv[1])
strings = subprocess.check_output(['strings', str(app/'Contents/MacOS/Rill')], text=True)
for hook in ('--smoke-report', '--reload-smoke', '--action-failure-smoke'):
    assert hook not in strings, f'Debug-only hook shipped: {hook}'
for config in sorted(Path('Examples').rglob('*.toml')):
    if 'schema_version' in config.read_text():
        subprocess.run([str(app/'Contents/Resources/bin/rillctl'), 'validate', '--config', str(config)], check=True)
PY
python3 scripts/verify-runtime.py \
    --app "$app" \
    --report .build/verification/runtime.json
