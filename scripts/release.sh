#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${RELEASE_DIR:-$root/.build/releases}"
archive="$out/Rill-0.1.0.xcarchive"
zip="$out/Rill-0.1.0-macos-arm64.zip"
mkdir -p "$out"
xcodebuild -project "$root/Rill.xcodeproj" -scheme Rill -configuration Release -destination 'generic/platform=macOS' -archivePath "$archive" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO archive
rm -f "$zip"
ditto -c -k --keepParent "$archive/Products/Applications/Rill.app" "$zip"
shasum -a 256 "$zip" | tee "$zip.sha256"
echo "Unsigned local artifact created: $zip"
echo "Signing and notarization require an owner-controlled environment."
