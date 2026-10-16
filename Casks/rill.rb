cask "rill" do
  version "0.1.0"
  sha256 "649d50c1bf1e8b74f05316785ed516f608ecbf7261611b373f786de63cc6ad43"

  url "https://github.com/AleckAstan/Rill/releases/download/v#{version}/Rill-#{version}-macos-arm64.zip"
  name "Rill"
  desc "Configurable native desktop bar for macOS"
  homepage "https://github.com/AleckAstan/Rill"

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "Rill.app"
  binary "#{appdir}/Rill.app/Contents/Resources/bin/rillctl"
end
