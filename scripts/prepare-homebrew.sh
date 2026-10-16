#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
archive="${1:-$root/.build/releases/Rill-0.1.0-macos-arm64.zip}"
checksum="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
mkdir -p "$root/Casks"
cat > "$root/Casks/rill.rb" <<RUBY
cask "rill" do
  version "0.1.0"
  sha256 "$checksum"

  url "https://github.com/AleckAstan/Rill/releases/download/v#{version}/Rill-#{version}-macos-arm64.zip"
  name "Rill"
  desc "Configurable native desktop bar for macOS"
  homepage "https://github.com/AleckAstan/Rill"

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "Rill.app"
  binary "#{appdir}/Rill.app/Contents/Resources/bin/rillctl"
end
RUBY
