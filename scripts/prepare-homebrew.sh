#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root/Info.plist")"
archive="${1:-$root/.build/releases/Rill-$version-macos-arm64.dmg}"
if [[ "$(basename "$archive")" != "Rill-$version-macos-arm64.dmg" ]]; then
    echo "error: expected Rill-$version-macos-arm64.dmg" >&2
    exit 1
fi
hdiutil verify "$archive" >/dev/null
codesign --verify --strict "$archive"
checksum="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
mkdir -p "$root/Casks"
cat > "$root/Casks/rill.rb" <<RUBY
cask "rill" do
  version "$version"
  sha256 "$checksum"

  url "https://github.com/AleckAstan/Rill/releases/download/v#{version}/Rill-#{version}-macos-arm64.dmg"
  name "Rill"
  desc "Configurable native desktop bar"
  homepage "https://github.com/AleckAstan/Rill"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Rill.app"
  binary "#{appdir}/Rill.app/Contents/Resources/bin/rillctl"

  caveats <<~EOS
    Rill is locally signed and is not notarized by Apple.
    If macOS blocks the first launch, open System Settings > Privacy & Security
    and choose Open Anyway for Rill after attempting to open the app.
    Initialize your configuration with: rillctl init
  EOS
end
RUBY
