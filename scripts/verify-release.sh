#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${RELEASE_DIR:-$root/.build/releases}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root/Info.plist")"
dmg="$out/Rill-$version-macos-arm64.dmg"
temporary="$(mktemp -d)"
mounted=false
cleanup() {
    if [[ "$mounted" == true ]]; then
        hdiutil detach "$temporary/volume" >/dev/null
    fi
    rm -rf "$temporary"
}
trap cleanup EXIT
(cd "$out" && shasum -a 256 -c "$(basename "$dmg").sha256")
hdiutil verify "$dmg"
codesign --verify --strict --verbose=2 "$dmg"
hdiutil attach "$dmg" -readonly -nobrowse -mountpoint "$temporary/volume" >/dev/null
mounted=true
app="$temporary/volume/Rill.app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign --verify --strict --verbose=2 "$app/Contents/Resources/bin/rillctl"
test "$(readlink "$temporary/volume/Applications")" = /Applications
test -s "$temporary/volume/Installation.txt"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" = "$version"
test "$("$app/Contents/Resources/bin/rillctl" --version)" = "rillctl $version"
"$app/Contents/Resources/bin/rillctl" init --config "$temporary/config.toml"
"$app/Contents/Resources/bin/rillctl" validate --config "$temporary/config.toml"
checksum="$(shasum -a 256 "$dmg" | cut -d ' ' -f 1)"
grep -Fq "sha256 \"$checksum\"" "$root/Casks/rill.rb"
grep -Fq 'macos-arm64.dmg"' "$root/Casks/rill.rb"
echo "Verified DMG contents, local signatures, CLI, configuration and cask checksum."
