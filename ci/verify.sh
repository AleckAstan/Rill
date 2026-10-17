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
python3 - <<'PY'
from pathlib import Path
import subprocess
app = Path('.build/releases/Rill-0.1.0.xcarchive/Products/Applications/Rill.app')
strings = subprocess.check_output(['strings', str(app/'Contents/MacOS/Rill')], text=True)
for hook in ('--smoke-report', '--reload-smoke', '--action-failure-smoke'):
    assert hook not in strings, f'Debug-only hook shipped: {hook}'
for config in sorted(Path('Examples').rglob('*.toml')):
    if 'schema_version' in config.read_text():
        subprocess.run([str(app/'Contents/Resources/bin/rillctl'), 'validate', '--config', str(config)], check=True)
PY
python3 scripts/verify-runtime.py \
    --app .build/releases/Rill-0.1.0.xcarchive/Products/Applications/Rill.app \
    --report .build/verification/runtime.json
