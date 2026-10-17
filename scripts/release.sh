#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${RELEASE_DIR:-$root/.build/releases}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root/Info.plist")"
identity="${SIGNING_IDENTITY:--}"
archive="$out/Rill-$version.xcarchive"
zip="$out/Rill-$version-macos-arm64.zip"
dmg="$out/Rill-$version-macos-arm64.dmg"
mkdir -p "$out"
xcodebuild -project "$root/Rill.xcodeproj" -scheme Rill -configuration Release -destination 'generic/platform=macOS' -archivePath "$archive" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO archive
app="$archive/Products/Applications/Rill.app"
codesign --force --sign "$identity" --options runtime --timestamp=none "$app/Contents/Resources/bin/rillctl"
codesign --force --sign "$identity" --options runtime --timestamp=none "$app"
codesign --verify --deep --strict --verbose=2 "$app"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
staging="$(mktemp -d "$out/dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Rill.app"
ln -s /Applications "$staging/Applications"
cp "$root/docs/user/installation.md" "$staging/Installation.txt"
hdiutil create -volname Rill -srcfolder "$staging" -format UDZO -ov "$dmg"
codesign --force --sign "$identity" --timestamp=none "$dmg"
codesign --verify --strict --verbose=2 "$dmg"
for artifact in "$zip" "$dmg"; do
    (cd "$out" && shasum -a 256 "$(basename "$artifact")") | tee "$artifact.sha256"
done
echo "Locally signed artifacts created: $dmg and $zip"
echo "These artifacts are not notarized. See docs/user/installation.md for first launch."
