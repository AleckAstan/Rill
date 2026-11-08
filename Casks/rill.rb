cask "rill" do
  version "0.2.0"
  sha256 "d9670c2aa11683ab5b138df3c45b3bf7bed626775cfd7cb63871586ff886b803"

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
