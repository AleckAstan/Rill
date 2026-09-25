#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$root/Rill.xcodeproj" -scheme Rill -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath "$root/.build/DerivedData" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO build

cli="$root/.build/DerivedData/Build/Products/Debug/Rill.app/Contents/Resources/bin/rillctl"
if [[ ! -x "$cli" ]]; then
    echo "error: bundled rillctl is missing or not executable at $cli" >&2
    exit 1
fi
